// lib/booking_screen.dart
import 'dart:ui';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

import 'slot_selection_screen.dart';

class BookingScreen extends StatefulWidget {
  final String location;
  final String parkingId;
  final String phoneNumber;

  const BookingScreen({
    super.key,
    required this.location,
    required this.parkingId,
    required this.phoneNumber,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // Controller (initialized immediately so it's always available)
  final DraggableScrollableController _draggableController =
      DraggableScrollableController();

  // API host settings
  String apiHost = 'backend-parking-bk8y.onrender.com';
  String apiScheme = 'https';

  // UI & form state
  String? selectedVehicle = "Car";
  final vehicleTypes = ["Car", "Bike"];
  final TextEditingController vehicleNumberController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  // Parking details (fetched)
  bool isLoading = true;
  double? lat;
  double? lng;
  int totalCarSlots = 0;
  int totalBikeSlots = 0;
  int availableCarSlots = 0;
  int availableBikeSlots = 0;

  // Sizes for image behaviour
  final double _imageStartFraction = 0.40; // 40% (when sheet at min)
  final double _sheetInitial = 0.60; // initial sheet size (60%)
  final double _sheetMin = 0.60;
  final double _sheetMax = 1.0;

  // Colours & theme (exact hex values from your spec)
  static const Color backgroundColor = Color(0xFFF7F7F9);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF7B61FF);
  static const Color gold = Color(0xFFFCC417);
  static const Color subtleText = Color(0xFF9AA0A6);
  static const Color titleText = Color(0xFF222222);
  // Added a light color for the dropdown text on change
  static const Color lightThemeDropdownText =
      titleText; // Using titleText for dark text on light background

  @override
  void initState() {
    super.initState();

    // Local dev fallback
    if (kIsWeb &&
        (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1')) {
      apiHost = '127.0.0.1:3000';
      apiScheme = 'http';
    }

    // Listen to changes so UI rebuilds when sheet moves
    _draggableController.addListener(_onSheetChanged);

    // Kick off data fetch
    _fetchParkingDetails();
  }

  void _onSheetChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _draggableController.removeListener(_onSheetChanged);
    _draggableController.dispose();
    vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchParkingDetails() async {
    setState(() => isLoading = true);
    try {
      final url = Uri.parse(
          '$apiScheme://$apiHost/api/parking_areas/${widget.parkingId}');
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          final dynamic maybeLat = data['lat'] ?? data['location']?['lat'];
          final dynamic maybeLng = data['lng'] ?? data['location']?['lng'];
          lat = maybeLat != null ? (maybeLat as num).toDouble() : null;
          lng = maybeLng != null ? (maybeLng as num).toDouble() : null;

          totalCarSlots = (data['total_car_slots'] ?? 0) as int;
          totalBikeSlots = (data['total_bike_slots'] ?? 0) as int;
          availableCarSlots = (data['available_car_slots'] ?? 0) as int;
          availableBikeSlots = (data['available_bike_slots'] ?? 0) as int;

          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _pickTime() async {
    // 💡 TIME PICKER CHANGE: Wrap the showTimePicker with Theme to enforce light mode
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          // Forcing a light theme for the Time Picker dialog
          data: ThemeData(
            brightness: Brightness.light,
            primaryColor: accent,
            colorScheme: ColorScheme.light(primary: accent),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  void _onConfirm() {
    if (vehicleNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter vehicle number')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SlotSelectionScreen(
          location: widget.location,
          parkingId: widget.parkingId,
          phoneNumber: widget.phoneNumber,
          selectedVehicle: selectedVehicle ?? "Car",
          vehicleNumber: vehicleNumberController.text.trim(),
          startDate: selectedDate,
          startTime: selectedTime,
        ),
      ),
    );
  }

  // Compute animation progress t in [0,1] where 0 = sheet at min, 1 = sheet at max
  double get _sheetProgress {
    try {
      if (!_draggableController.isAttached) {
        final t0 = ((_sheetInitial - _sheetMin) / (_sheetMax - _sheetMin))
            .clamp(0.0, 1.0);
        return t0;
      }
      final size = _draggableController.size;
      final t = ((size - _sheetMin) / (_sheetMax - _sheetMin)).clamp(0.0, 1.0);
      return t;
    } catch (_) {
      final t0 = ((_sheetInitial - _sheetMin) / (_sheetMax - _sheetMin))
          .clamp(0.0, 1.0);
      return t0;
    }
  }

  Widget _buildTopImage(double screenHeight) {
    final imageUrl =
        "https://images.pexels.com/photos/210019/pexels-photo-210019.jpeg";

    final double t = _sheetProgress;
    final double startHeight = screenHeight * _imageStartFraction;
    final double endHeight = max(120.0, screenHeight * 0.12);
    final double imageHeight = lerpDouble(startHeight, endHeight, t)!;
    final double opacity = lerpDouble(1.0, 0.70, t)!;
    final double translateY = lerpDouble(0.0, -24.0, t)!;

    // Positioned so it sits above the sheet
    return Positioned(
      top: translateY,
      left: 0,
      right: 0,
      child: SizedBox(
        height: imageHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Image with rounded bottom corners
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(26),
                bottomRight: Radius.circular(26),
              ),
              child: Opacity(
                opacity: opacity,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: imageHeight,
                  loadingBuilder: (c, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (_, __, ___) {
                    return Container(
                        color: Colors.grey[300],
                        child:
                            const Center(child: Icon(Icons.image, size: 48)));
                  },
                ),
              ),
            ),

            // Back button (floating circle) - overlay on top-left (keeps breathing space)
            Positioned(
              top: 16,
              left: 14,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: cardBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: IconButton(
                    splashRadius: 22,
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),

            // Parking name bottom-left overlay (white text with subtle shadow)
            Positioned(
              left: 18,
              bottom: 16,
              child: Text(
                widget.location,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.55),
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    // bottom fixed CTA used in the sheet
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          // Softer shadow that blends with the background
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "₹ 30",
                style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: titleText),
              ),
              Text(
                "/hr",
                style: GoogleFonts.poppins(fontSize: 13, color: subtleText),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              "Confirm",
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheetContent(BoxConstraints constraints) {
    // NOTE: exact padding required by you is applied to this main Column's SingleChildScrollView
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // drag indicator
          Center(
            child: Container(
              width: 60,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 20), // header & title gap = 20px (rule 7)

          // Header / Title area (title size within 23-26 range? you requested 23-26)
          Text("Book Your Parking",
              style: GoogleFonts.poppins(
                fontSize: 24, // between 23-26
                fontWeight: FontWeight.w600,
                color: titleText,
              )),
          const SizedBox(height: 16), // title & search bar gap = 16px (rule 7)

          Text("Car Parking",
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: subtleText,
                  fontWeight: FontWeight.w400)),

          const SizedBox(height: 8),

          Text(widget.location,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: titleText)),
          const SizedBox(height: 6),

          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: subtleText),
              const SizedBox(width: 6),
              Text(
                (lat != null && lng != null)
                    ? "${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}"
                    : "Loading location...",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: subtleText,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18), // section gap ~18-22

          // Vehicle type + number row - card-like appearance (rounded card)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Vehicle Type",
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: titleText.withOpacity(0.8))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        // 💡 VEHICLE TYPE CHANGE 1: Use a Theme widget to control the appearance of the native dropdown
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            // Enforce light theme colors for the dropdown menu
                            canvasColor: cardBg,
                            colorScheme: ColorScheme.light(primary: accent),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedVehicle,
                              // 💡 VEHICLE TYPE CHANGE 2: Apply the light theme text color to the selected item and menu items
                              selectedItemBuilder: (BuildContext context) {
                                return vehicleTypes.map((String value) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      value,
                                      style: GoogleFonts.poppins(
                                          color:
                                              lightThemeDropdownText, // Apply dark text color
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  );
                                }).toList();
                              },
                              items: vehicleTypes
                                  .map((v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v,
                                          style: GoogleFonts.poppins(
                                              color:
                                                  titleText)))) // Menu item text is dark
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => selectedVehicle = v),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Vehicle Number",
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: titleText.withOpacity(0.8))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: vehicleNumberController,
                        decoration: InputDecoration(
                          hintText: "Enter number plate",
                          hintStyle: GoogleFonts.poppins(
                              fontSize: 13, color: subtleText),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        style: GoogleFonts.poppins(color: titleText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Book a slot label
          Text("Book a slot",
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600, color: titleText)),
          const SizedBox(height: 14),

          // Day pills
          Text("Day",
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: titleText.withOpacity(0.9),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final day = DateTime.now().add(Duration(days: idx));
                final label = idx == 0
                    ? "Today"
                    : (idx == 1 ? "Tomorrow" : DateFormat('EEE').format(day));
                final dateLabel = "${day.day} ${DateFormat('MMM').format(day)}";
                final bool isSelected = selectedDate.year == day.year &&
                    selectedDate.month == day.month &&
                    selectedDate.day == day.day;

                return GestureDetector(
                  onTap: () => setState(() => selectedDate = day),
                  child: Container(
                    width: 100,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? accent : cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: accent.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4))
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: isSelected ? Colors.white : titleText)),
                        const SizedBox(height: 6),
                        Text(dateLabel,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color:
                                    isSelected ? Colors.white70 : subtleText)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // Time selector
          Text("Time",
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: titleText.withOpacity(0.9),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          // 💡 TIME SELECTION CONTAINER CHANGE:
          GestureDetector(
            onTap: _pickTime,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                // Change background color to light theme
                color: cardBg, // Use cardBg (white) for light theme
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  Text(
                    selectedTime.format(context).toLowerCase(),
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        // Change text color to dark theme
                        color: titleText,
                        fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20, color: Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Availability & Price row (card row)
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Availability",
                      style:
                          GoogleFonts.poppins(fontSize: 12, color: subtleText)),
                  const SizedBox(height: 6),
                  Text(
                      "Cars: $availableCarSlots  •  Bikes: $availableBikeSlots",
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: titleText)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Price",
                      style:
                          GoogleFonts.poppins(fontSize: 12, color: subtleText)),
                  const SizedBox(height: 6),
                  Text("₹30/hr",
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: titleText)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),
          // extra spacing so the scroll content doesn't clash with fixed CTA
          SizedBox(height: max(40.0, 60)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: backgroundColor,
      // Bottom nav is handled by sheet CTA; page-level SafeArea ensures notch & dynamic island safety
      body: SafeArea(
        top: true,
        bottom: true,
        child: Stack(
          children: [
            // background color (fills full area inside SafeArea)
            Container(color: backgroundColor),

            // top image (positioned)
            LayoutBuilder(builder: (context, constraints) {
              return _buildTopImage(constraints.maxHeight);
            }),

            // Draggable sheet (keeps content centered and notch-safe)
            DraggableScrollableSheet(
              controller: _draggableController,
              initialChildSize: _sheetInitial,
              minChildSize: _sheetMin,
              maxChildSize: _sheetMax,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x20000000),
                        blurRadius: 18,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              controller: scrollController,
                              physics: const BouncingScrollPhysics(),
                              // IMPORTANT: apply EXACT padding here as requested
                              child: Column(
                                children: [
                                  const SizedBox(height: 8),
                                  // bottom sheet content has its own inner padding (18,18)
                                  _buildBottomSheetContent(constraints),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // FIXED CTA ROW (keeps safe area at bottom)
                      SafeArea(
                        top: false,
                        child: _buildBottomActionBar(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
