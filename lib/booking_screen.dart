// booking_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'slot_selection_screen.dart';
import 'package:flutter/foundation.dart';

class AppColors {
  static const Color appBackground = Color(0xFF1C1C1E);
  static const Color cardSurface = Color(0xFF2C2C2E);
  static const Color appBarColor = Color(0xFF1C1C1E);
  static const Color infoItemBg = Color(0xFF3A3A3C);
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB0B0B5);
  static const Color hintText = Color(0xFF8E8E93);
  static const Color outlinedButtonColor = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF000000);
  static const Color elevatedButtonBg = Color(0xFFFFFFFF);
  static const Color markerColor = Color(0xFFAAAAAA);
}

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
  String apiHost = "backend-parking-bk8y.onrender.com";
  String apiScheme = "https";

  String? selectedVehicle;
  DateTime? startDate;
  TimeOfDay? startTime;

  final TextEditingController vehicleNumberController = TextEditingController();

  int totalCarSlots = 0;
  int totalBikeSlots = 0;
  int availableCar = 0;
  int availableBike = 0;
  int bookedCar = 0;
  int bookedBike = 0;

  List<String> vehicleTypes = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    if (kIsWeb &&
        (Uri.base.host == "localhost" || Uri.base.host == "127.0.0.1")) {
      apiHost = "127.0.0.1:3000";
      apiScheme = "http";
    }

    _fetchParkingAreaDetails();
  }

  Future<void> _fetchParkingAreaDetails() async {
    setState(() => isLoading = true);

    try {
      final url = "$apiScheme://$apiHost/api/parking_areas/${widget.parkingId}";

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          totalCarSlots = data["total_car_slots"] ?? 0;
          totalBikeSlots = data["total_bike_slots"] ?? 0;

          availableCar = data["available_car_slots"] ?? 0;
          availableBike = data["available_bike_slots"] ?? 0;

          bookedCar = totalCarSlots - availableCar;
          bookedBike = totalBikeSlots - availableBike;

          vehicleTypes = [];
          if (totalCarSlots > bookedCar) vehicleTypes.add("Car");
          if (totalBikeSlots > bookedBike) vehicleTypes.add("Bike");

          isLoading = false;
        });
      } else {
        isLoading = false;
      }
    } catch (e) {
      isLoading = false;
    }
  }

  void _openNextPage() {
    if (selectedVehicle == null ||
        vehicleNumberController.text.isEmpty ||
        startDate == null ||
        startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all details")),
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
          selectedVehicle: selectedVehicle!,
          vehicleNumber: vehicleNumberController.text,
          startDate: startDate!,
          startTime: startTime!,
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) setState(() => startDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
    );

    if (picked != null) setState(() => startTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        title: const Text("Book Parking"),
        backgroundColor: AppColors.appBarColor,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Vehicle Details",
                      style: GoogleFonts.poppins(
                          fontSize: 20, color: AppColors.primaryText),
                    ),
                    const SizedBox(height: 14),

                    // VEHICLE TYPE
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.cardSurface,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        labelText: "Vehicle Type",
                        labelStyle:
                            const TextStyle(color: AppColors.secondaryText),
                      ),
                      value: selectedVehicle,
                      items: vehicleTypes
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => selectedVehicle = v),
                    ),
                    const SizedBox(height: 16),

                    // VEHICLE NUMBER
                    TextField(
                      controller: vehicleNumberController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.cardSurface,
                        labelText: "Vehicle Number",
                        labelStyle:
                            const TextStyle(color: AppColors.secondaryText),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      style: const TextStyle(color: AppColors.primaryText),
                    ),
                    const SizedBox(height: 30),

                    Text(
                      "Entry Time",
                      style: GoogleFonts.poppins(
                          fontSize: 20, color: AppColors.primaryText),
                    ),

                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: AppColors.hintText),
                            const SizedBox(width: 12),
                            Text(
                              startDate == null
                                  ? "Select date"
                                  : "${startDate!.day}/${startDate!.month}/${startDate!.year}",
                              style: GoogleFonts.poppins(
                                  fontSize: 16, color: AppColors.primaryText),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _pickTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time,
                                color: AppColors.hintText),
                            const SizedBox(width: 12),
                            Text(
                              startTime == null
                                  ? "Select entry time"
                                  : startTime!.format(context),
                              style: GoogleFonts.poppins(
                                  fontSize: 16, color: AppColors.primaryText),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _openNextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.elevatedButtonBg,
                          foregroundColor: AppColors.darkText,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Select Slot",
                          style: GoogleFonts.poppins(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
