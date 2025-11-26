import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO; // ✅ NEW

import 'package:flutter/foundation.dart';
import 'success_screen.dart';

// Import the Razorpay flutter package.
import 'package:razorpay_flutter/razorpay_flutter.dart';

// --- THEME COLORS ---
class AppColors {
  static const Color appBackground = Color(0xFF1C1C1E);
  static const Color cardSurface = Color(0xFF2C2C2E);
  static const Color appBarColor = Color(0xFF1C1C1E);
  static const Color searchBarColor = Color(0xFF2C2C2E);
  static const Color infoItemBg = Color(0xFF3A3A3C);

  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB0B0B5);
  static const Color hintText = Color(0xFF8E8E93);
  static const Color darkText = Color(0xFF000000); // For white buttons

  static const Color markerColor =
      Color.fromARGB(255, 215, 215, 215); // Blue accent
  static const Color routeColor = Color.fromARGB(255, 255, 255, 255);
  static const Color outlinedButtonColor = Color.fromARGB(255, 255, 255, 255);
  static const Color elevatedButtonBg = Color(0xFFFFFFFF);

  static const Color shadow = Color.fromRGBO(0, 0, 0, 0.3);
  static const Color errorRed = Color(0xFFD32F2F); // A dark red for errors
}
// --- END THEME COLORS ---

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
  _BookingScreenState createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late IO.Socket socket; // ✅ NEW
  String? selectedVehicle;
  DateTime? startDate;
  TimeOfDay? startTime;
  // --- UPDATED: Use Set<int> to track selected slot numbers (Hybrid Model) ---
  Set<int> selectedSlotNumbers = {};
  // --------------------------------------------------------------------------
  final TextEditingController _vehicleNumberController =
      TextEditingController();
  List<dynamic> allSlots = [];
  bool isLoading = true;
  int totalCarSlots = 0;
  int totalBikeSlots = 0;
  int availableCarSlots = 0;
  int bookedCarSlots = 0;
  int availableBikeSlots = 0;
  int bookedBikeSlots = 0;
  String apiHost = 'backend-parking-bk8y.onrender.com';
  String apiScheme = 'https'; // Default to https

  List<String> vehicleTypes = ["Car", "Bike"];

  late Razorpay _razorpay;
  final String razorpayKey = "rzp_live_R6QQALUuJwgDaD";
  final double pricePerSlot = 1.0;
  Future<bool> _holdSlot(int slotNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$apiScheme://$apiHost/api/holds'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "parking_id": int.parse(widget.parkingId),
          "slot_number": slotNumber,
          "vehicle_type": selectedVehicle!.toLowerCase(),
          "phone": widget.phoneNumber,
        }),
      );

      if (response.statusCode == 200) {
        return true; // ✅ hold created
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    // Host setup
    if (kIsWeb &&
        (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1')) {
      apiHost = '127.0.0.1:3000';
      apiScheme = 'http';
    }
    _fetchParkingAreaDetails();
    _initSocket(); // ✅ NEW
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _initSocket() {
    socket = IO.io(
      '$apiScheme://$apiHost',
      IO.OptionBuilder()
          .setTransports(['websocket']) // ✅ No polling
          .enableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      print("✅ Connected to WebSocket");

      if (selectedVehicle != null) {
        socket.emit("join_parking", {
          "parking_id": widget.parkingId,
          "vehicle_type": selectedVehicle!.toLowerCase(),
        });
      }
    });

    socket.on("slot_update", (data) {
      print("📡 Slot update received → $data");

      final updatedSlot = data['slot_number'];
      final updatedStatus = data['status'];

      setState(() {
        allSlots = allSlots.map((slot) {
          if (slot['slot_number'] == updatedSlot) {
            return {...slot, "status": updatedStatus};
          }
          return slot;
        }).toList();

// Remove if user selected & now held/booked
        // Remove selection if slot not available anymore
        if (selectedSlotNumbers.contains(updatedSlot)) {
          if (updatedStatus != "selected") {
            selectedSlotNumbers.remove(updatedSlot);
          }
        }
      });
    });

    socket.onDisconnect((_) => print("❌ Disconnected from socket"));
  }

  @override
  void dispose() {
    socket.dispose(); // ✅ prevent memory leaks
    _razorpay.clear();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _showBookingProgressDialog();
    _confirmBooking(response.paymentId);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showErrorDialog("Payment Failed: ${response.message}");
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showErrorDialog("External Wallet: ${response.walletName}");
  }

  Future<void> _fetchParkingAreaDetails() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
            '$apiScheme://$apiHost/api/parking_areas/${widget.parkingId}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          totalCarSlots = data['total_car_slots'] ?? 0;
          totalBikeSlots = data['total_bike_slots'] ?? 0;
          availableCarSlots = data['available_car_slots'] ?? 0;
          availableBikeSlots = data['available_bike_slots'] ?? 0;
          // Note: Backend now tracks booked_slots dynamically
          bookedCarSlots = totalCarSlots - availableCarSlots;
          bookedBikeSlots = totalBikeSlots - availableBikeSlots;

          vehicleTypes = [];
          if (totalCarSlots > bookedCarSlots) vehicleTypes.add("Car");
          if (totalBikeSlots > bookedBikeSlots) vehicleTypes.add("Bike");
        });
        if (selectedVehicle != null) {
          await _fetchAllSlots();
        } else {
          setState(() => isLoading = false);
        }
      } else {
        _showErrorDialog(
            "Failed to fetch parking details: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (error) {
      _showErrorDialog("Error fetching parking details: $error");
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchAllSlots() async {
    if (selectedVehicle == null) return;
    setState(() => isLoading = true);
    try {
      final url =
          '$apiScheme://$apiHost/api/parking_areas/${widget.parkingId}/slots?vehicle_type=${selectedVehicle!.toLowerCase()}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          allSlots = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        _showErrorDialog("Failed to load slots: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (error) {
      _showErrorDialog("Error loading slots: $error");
      setState(() => isLoading = false);
    }
  }

  void _startPayment() {
    // --- UPDATED: Use selectedSlotNumbers ---
    if (selectedVehicle != null &&
        _vehicleNumberController.text.isNotEmpty &&
        selectedSlotNumbers.isNotEmpty &&
        startDate != null &&
        startTime != null) {
      final int totalAmount = (selectedSlotNumbers.length * pricePerSlot * 100)
          .toInt(); // Amount in paise
      // ----------------------------------------

      var options = {
        'key': razorpayKey,
        'amount': totalAmount,
        'name': 'ParkEasy Booking',
        // --- UPDATED: Use selectedSlotNumbers.length ---
        'description':
            'Parking Booking for ${selectedSlotNumbers.length} slots',
        // ------------------------------------------------
        'prefill': {
          'contact': widget.phoneNumber,
          'email': 'testuser@razorpay.com'
        },
        'notes': {
          'location': widget.location,
          'vehicle_type': selectedVehicle,
          // --- UPDATED: Use selectedSlotNumbers.join(',') ---
          'slots': selectedSlotNumbers.join(','),
          // ----------------------------------------------------
        }
      };

      try {
        _razorpay.open(options);
      } catch (e) {
        _showErrorDialog("Error starting payment: $e");
      }
    } else {
      _showErrorDialog(
          "Please complete all selections (Vehicle, Number Plate, Time, Slot)");
    }
  }

  Future<void> _confirmBooking(String? paymentId) async {
    final entryDateTime = DateTime(
      startDate!.year,
      startDate!.month,
      startDate!.day,
      startTime!.hour,
      startTime!.minute,
    );

    try {
      final List<int> bookedSlots = [];

      // --- UPDATED: Loop through selected Slot Numbers (int) ---
      for (int slotNumber in selectedSlotNumbers) {
        final response = await http.post(
          Uri.parse('$apiScheme://$apiHost/api/bookings'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'parking_id': int.parse(widget.parkingId),
            // --- CRITICAL CHANGE: Send slot_number, not slot_id ---
            'slot_number': slotNumber,
            // ------------------------------------------------------
            'vehicle_type': selectedVehicle!.toLowerCase(),
            'number_plate': _vehicleNumberController.text,
            'entry_time': entryDateTime.toIso8601String(),
            'phone': widget.phoneNumber,
            'payment_id': paymentId,
          }),
        );

        if (response.statusCode != 200) {
          // If a slot fails to book, show error and stop immediately
          _showErrorDialog(
              "Failed to book slot $slotNumber: ${jsonDecode(response.body)['message'] ?? response.body}");
          return;
        } else {
          // Add the successfully booked slot number to the list for the success screen
          bookedSlots.add(slotNumber);
        }
      }
      // -------------------------------------------------------------

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context); // Dismiss the progress dialog

      if (mounted) {
        await _fetchParkingAreaDetails(); // Refresh details

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SuccessScreen(
              location: widget.location,
              vehicleType: selectedVehicle!,
              slots: bookedSlots, // List of slot numbers
              entryDateTime: entryDateTime,
              phoneNumber: widget.phoneNumber,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) Navigator.pop(context); // Dismiss the progress dialog
      _showErrorDialog("Error confirming booking: $error");
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.markerColor,
              onPrimary: AppColors.primaryText,
              surface: AppColors.cardSurface,
              onSurface: AppColors.primaryText,
            ),
            dialogBackgroundColor: AppColors.cardSurface,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => startDate = picked);
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.markerColor,
              onPrimary: AppColors.primaryText,
              surface: AppColors.cardSurface,
              onSurface: AppColors.primaryText,
            ),
            dialogBackgroundColor: AppColors.cardSurface,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => startTime = picked);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.error_outline, color: AppColors.errorRed),
              SizedBox(width: 8),
              Text(
                "Booking Error",
                style: TextStyle(color: AppColors.primaryText),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: AppColors.primaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK",
                  style: TextStyle(color: AppColors.markerColor)),
            ),
          ],
        );
      },
    );
  }

  void _showBookingProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: const [
              CircularProgressIndicator(color: AppColors.primaryText),
              SizedBox(width: 20),
              Text(
                "Confirming booking...",
                style: TextStyle(color: AppColors.primaryText),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        title: const Text("Book a Parking Spot"),
        elevation: 0,
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.primaryText,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.appBarColor, // Match AppBar
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Book at ${widget.location}",
                    style: GoogleFonts.poppins(
                      color: AppColors.primaryText,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Reserve your parking space now",
                    style: GoogleFonts.poppins(
                      color: AppColors.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSlotCount(Icons.directions_car, "Cars",
                          availableCarSlots, bookedCarSlots),
                      _buildSlotCount(Icons.motorcycle, "Bikes",
                          availableBikeSlots, bookedBikeSlots),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Parking Details"),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: "Select Vehicle Type",
                              labelStyle:
                                  const TextStyle(color: AppColors.hintText),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.outlinedButtonColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.primaryText),
                              ),
                              prefixIcon: const Icon(Icons.directions_car,
                                  color: AppColors.hintText),
                              filled: true,
                              fillColor: AppColors.infoItemBg,
                            ),
                            style:
                                const TextStyle(color: AppColors.primaryText),
                            value: selectedVehicle,
                            items: vehicleTypes.map((vehicle) {
                              return DropdownMenuItem(
                                value: vehicle,
                                child: Text(vehicle),
                              );
                            }).toList(),
                            onChanged: vehicleTypes.isEmpty
                                ? null
                                : (value) {
                                    setState(() {
                                      selectedVehicle = value;
                                      selectedSlotNumbers.clear();
                                    });

                                    // ✅ re-fetch slots
                                    _fetchAllSlots();

                                    // ✅ join correct WebSocket room
                                    socket.emit("join_parking", {
                                      "parking_id": widget.parkingId,
                                      "vehicle_type":
                                          selectedVehicle!.toLowerCase(),
                                    });
                                  },
                            dropdownColor: AppColors.cardSurface,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: AppColors.hintText),
                            disabledHint: const Text(
                              "No available vehicle types",
                              style: TextStyle(color: AppColors.hintText),
                            ),
                          ),
                          if (selectedVehicle != null) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: _vehicleNumberController,
                              style:
                                  const TextStyle(color: AppColors.primaryText),
                              decoration: InputDecoration(
                                labelText: selectedVehicle == "Car"
                                    ? "Car Number Plate"
                                    : "Bike Number Plate",
                                labelStyle:
                                    const TextStyle(color: AppColors.hintText),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.outlinedButtonColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.primaryText),
                                ),
                                prefixIcon: Icon(
                                  selectedVehicle == "Car"
                                      ? Icons.directions_car
                                      : Icons.motorcycle,
                                  color: AppColors.hintText,
                                ),
                                filled: true,
                                fillColor: AppColors.infoItemBg,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Entry Timing"),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => _selectStartDate(context),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: AppColors.appBackground)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.infoItemBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.calendar_today,
                                      color: AppColors.markerColor),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Entry Date",
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.secondaryText),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        startDate != null
                                            ? "${startDate!.day}/${startDate!.month}/${startDate!.year}"
                                            : "Select Entry Date",
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: AppColors.primaryText,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios,
                                    size: 16, color: AppColors.hintText),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _selectStartTime(context),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.infoItemBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.access_time,
                                      color: AppColors.markerColor),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Entry Time",
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.secondaryText),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        startTime != null
                                            ? startTime!.format(context)
                                            : "Select Entry Time",
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: AppColors.primaryText,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios,
                                    size: 16, color: AppColors.hintText),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Select Parking Slots"),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLegendItem(AppColors.infoItemBg, "Available"),
                            _buildLegendItem(AppColors.markerColor, "Selected"),
                            _buildLegendItem(Colors.orangeAccent, "Held"),
                            _buildLegendItem(
                                AppColors.outlinedButtonColor, "Booked"),
                          ],
                        ),
                        const SizedBox(height: 20),
                        isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                color: AppColors.primaryText,
                              ))
                            : selectedVehicle == null
                                ? const Center(
                                    child: Text(
                                    "Please select a vehicle type",
                                    style: TextStyle(
                                        color: AppColors.secondaryText),
                                  ))
                                : allSlots.isEmpty
                                    ? const Center(
                                        child: Text(
                                            "No slots found for this vehicle type",
                                            style: TextStyle(
                                                color:
                                                    AppColors.secondaryText)))
                                    : Wrap(
                                        spacing: 10.0,
                                        runSpacing: 10.0,
                                        children: allSlots.map((slot) {
                                          // --- UPDATED: Use slotNumber (int) for selection ---
                                          final slotNumber = int.parse(
                                              slot['slot_number'].toString());

                                          final isSelected = selectedSlotNumbers
                                              .contains(slotNumber);
                                          final String status =
                                              slot['status'] ?? "available";
                                          final bool isBooked =
                                              status == "booked";
                                          final bool isHeld = status == "held";

                                          // --- Define colors based on state ---
                                          final Color slotColor;
                                          final Color textColor;

                                          if (isBooked) {
                                            slotColor =
                                                Colors.grey.shade600; // booked
                                            textColor = AppColors.secondaryText;
                                          } else if (isHeld) {
                                            slotColor =
                                                Colors.orangeAccent; // held
                                            textColor = Colors.white;
                                          } else if (isSelected) {
                                            slotColor = AppColors
                                                .markerColor; // selected
                                            textColor = Colors.white;
                                          } else {
                                            slotColor = AppColors
                                                .infoItemBg; // available
                                            textColor = AppColors.primaryText;
                                          }

                                          // --- End of color definitions ---

                                          return GestureDetector(
                                            onTap: (isBooked || isHeld)
                                                ? null
                                                : () async {
                                                    if (isSelected) {
                                                      // optional: release hold when deselect
                                                      selectedSlotNumbers
                                                          .remove(slotNumber);
                                                      setState(() {});
                                                      return;
                                                    }

                                                    final success =
                                                        await _holdSlot(
                                                            slotNumber);

                                                    if (!success) {
                                                      _showErrorDialog(
                                                          "Slot already taken or unavailable.");
                                                      return;
                                                    }

                                                    selectedSlotNumbers
                                                        .add(slotNumber);
                                                    setState(() {});
                                                  },
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 200),
                                              width: 65,
                                              height: 65,
                                              decoration: BoxDecoration(
                                                color: slotColor, // CHANGED
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: isSelected
                                                    ? [
                                                        BoxShadow(
                                                          color:
                                                              AppColors.shadow,
                                                          blurRadius: 8,
                                                          offset: const Offset(
                                                              0, 2),
                                                        )
                                                      ]
                                                    : [],
                                              ),
                                              child: Center(
                                                child: Text(
                                                  "$slotNumber",
                                                  style: GoogleFonts.poppins(
                                                    color: textColor, // CHANGED
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.elevatedButtonBg,
                        foregroundColor: AppColors.darkText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _startPayment,
                      child: Text(
                        "Book Now (${selectedSlotNumbers.length} Slot${selectedSlotNumbers.length == 1 ? '' : 's'} - ₹${(selectedSlotNumbers.length * pricePerSlot).toStringAsFixed(2)})",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.markerColor, // Use accent color
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style:
              GoogleFonts.poppins(fontSize: 12, color: AppColors.secondaryText),
        ),
      ],
    );
  }

  Widget _buildSlotCount(
      IconData icon, String label, int available, int booked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.infoItemBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryText),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$available / ${available + booked}",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              Text(
                "$label (Avail/Total)",
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.secondaryText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
