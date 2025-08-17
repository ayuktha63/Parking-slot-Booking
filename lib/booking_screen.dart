import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:parking_booking/SuccessAnimationScreen.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'success_screen.dart';

// Import the Razorpay flutter package. Flutter's build system will
// automatically select the correct platform implementation.
import 'package:razorpay_flutter/razorpay_flutter.dart';

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
  String? selectedVehicle;
  DateTime? startDate;
  TimeOfDay? startTime;
  Set<String> selectedSlotIds = {};
  final TextEditingController _vehicleNumberController = TextEditingController();
  List<dynamic> allSlots = [];
  bool isLoading = true;
  int totalCarSlots = 0;
  int totalBikeSlots = 0;
  int availableCarSlots = 0;
  int bookedCarSlots = 0;
  int availableBikeSlots = 0;
  int bookedBikeSlots = 0;
  String apiHost = '10.0.2.2';
  List<String> vehicleTypes = ["Car", "Bike"];

  // Razorpay instance
  late Razorpay _razorpay;

  // NOTE: Storing API keys like this is a security risk.
  // In a production app, these should be handled securely on a server-side.
  final String razorpayKey = "rzp_live_R6QQALUuJwgDaD";
  
  // Assuming a fixed price per slot for simplicity
  final double pricePerSlot = 1.0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      apiHost = '127.0.0.1';
    }
    _fetchParkingAreaDetails();

    // Initialize Razorpay instance with the key
    _razorpay = Razorpay();

    // Set up a single listener for all events
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    // Unregister all listeners before disposing using the clear method
    _razorpay.clear();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // Payment was successful, now confirm the booking
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
        Uri.parse('http://$apiHost:3000/api/parking_areas/${widget.parkingId}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          totalCarSlots = data['total_car_slots'] ?? 0;
          totalBikeSlots = data['total_bike_slots'] ?? 0;
          availableCarSlots = data['available_car_slots'] ?? 0;
          availableBikeSlots = data['available_bike_slots'] ?? 0;
          bookedCarSlots = totalCarSlots - availableCarSlots;
          bookedBikeSlots = totalBikeSlots - availableBikeSlots;
          vehicleTypes = [];
          if (availableCarSlots > 0) vehicleTypes.add("Car");
          if (availableBikeSlots > 0) vehicleTypes.add("Bike");
        });
        if (selectedVehicle != null) {
          await _fetchAllSlots();
        } else {
          setState(() => isLoading = false);
        }
      } else {
        _showErrorDialog("Failed to fetch parking details: ${response.statusCode}");
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
      final url = 'http://$apiHost:3000/api/parking_areas/${widget.parkingId}/slots?vehicle_type=${selectedVehicle!.toLowerCase()}';
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

  // The main payment initiation function
  void _startPayment() {
    if (selectedVehicle != null &&
        _vehicleNumberController.text.isNotEmpty &&
        selectedSlotIds.isNotEmpty &&
        startDate != null &&
        startTime != null) {
      final int totalAmount = (selectedSlotIds.length * pricePerSlot * 100).toInt(); // Amount in paise
      
      var options = {
        'key': razorpayKey,
        'amount': totalAmount,
        'name': 'ParkEasy Booking',
        'description': 'Parking Booking for ${selectedSlotIds.length} slots',
        'prefill': {'contact': widget.phoneNumber, 'email': 'testuser@razorpay.com'},
        'notes': {
          'location': widget.location,
          'vehicle_type': selectedVehicle,
          'slots': selectedSlotIds.join(','),
        }
      };
      
      try {
        _razorpay.open(options);
      } catch (e) {
        _showErrorDialog("Error starting payment: $e");
      }
    } else {
      _showErrorDialog("Please complete all selections");
    }
  }

  Future<void> _confirmBooking(String? paymentId) async {
    final entryDateTime = DateTime(
      startDate!.year, startDate!.month, startDate!.day,
      startTime!.hour, startTime!.minute,
    );

    try {
      final List<int> bookedSlots = [];

      for (String slotId in selectedSlotIds) {
        final response = await http.post(
          Uri.parse('http://$apiHost:3000/api/bookings'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'parking_id': widget.parkingId,
            'slot_id': slotId,
            'vehicle_type': selectedVehicle!.toLowerCase(),
            'number_plate': _vehicleNumberController.text,
            'entry_time': entryDateTime.toIso8601String(),
            'phone': widget.phoneNumber,
            'payment_id': paymentId, // Pass the payment ID to your backend
          }),
        );

        if (response.statusCode != 200) {
          _showErrorDialog("Failed to book slot: ${response.body}");
          return;
        } else {
          final slot = allSlots.firstWhere((s) => s['_id'] == slotId, orElse: () => null);
          if (slot != null) {
            bookedSlots.add(slot['slot_number'] as int);
          }
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.pop(context); // Dismiss the progress dialog

      if (mounted) {
        await _fetchParkingAreaDetails();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SuccessScreen(
              location: widget.location,
              vehicleType: selectedVehicle!,
              slots: bookedSlots,
              entryDateTime: entryDateTime,
              phoneNumber: widget.phoneNumber,
            ),
          ),
        );
      }
    } catch (error) {
      Navigator.pop(context); // Dismiss the progress dialog
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3F51B5),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3F51B5),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text("Booking Error"),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK", style: TextStyle(color: Color(0xFF3F51B5))),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Confirming booking..."),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Book a Parking Spot"),
        elevation: 0,
        backgroundColor: const Color(0xFF3F51B5),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF3F51B5),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Reserve your parking space now",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSlotCount(Icons.directions_car, "Cars", availableCarSlots, bookedCarSlots),
                      _buildSlotCount(Icons.motorcycle, "Bikes", availableBikeSlots, bookedBikeSlots),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
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
                              labelStyle: const TextStyle(color: Color(0xFF3F51B5)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF3F51B5)),
                              ),
                              prefixIcon: const Icon(Icons.directions_car, color: Color(0xFF3F51B5)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: selectedVehicle,
                            items: vehicleTypes.map((vehicle) {
                              return DropdownMenuItem(
                                value: vehicle,
                                child: Text(vehicle),
                              );
                            }).toList(),
                            onChanged: vehicleTypes.isEmpty
                                ? null
                                : (value) => setState(() {
                              selectedVehicle = value;
                              selectedSlotIds.clear();
                              _fetchAllSlots();
                            }),
                            dropdownColor: Colors.white,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF3F51B5)),
                            disabledHint: const Text("No available vehicle types"),
                          ),
                          if (selectedVehicle != null) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: _vehicleNumberController,
                              decoration: InputDecoration(
                                labelText: selectedVehicle == "Car" ? "Car Number Plate" : "Bike Number Plate",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: Icon(
                                  selectedVehicle == "Car" ? Icons.directions_car : Icons.motorcycle,
                                  color: const Color(0xFF3F51B5),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Entry & Exit Timing"),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
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
                              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3F51B5).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.calendar_today, color: Color(0xFF3F51B5)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Entry Date",
                                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        startDate != null ? "${startDate!.day}/${startDate!.month}/${startDate!.year}" : "Select Entry Date",
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
                                    color: const Color(0xFF3F51B5).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.access_time, color: Color(0xFF3F51B5)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Entry Time",
                                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        startTime != null ? startTime!.format(context) : "Select Entry Time",
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
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
                            _buildLegendItem(Colors.grey[300]!, "Available"),
                            _buildLegendItem(const Color(0xFF4CAF50), "Selected"),
                            _buildLegendItem(Colors.red[300]!, "Booked"),
                          ],
                        ),
                        const SizedBox(height: 20),
                        isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : selectedVehicle == null
                            ? const Center(child: Text("Please select a vehicle type"))
                            : allSlots.isEmpty
                            ? const Center(child: Text("No slots found for this vehicle type"))
                            : Wrap(
                          spacing: 10.0,
                          runSpacing: 10.0,
                          children: allSlots.map((slot) {
                            final slotId = slot['_id'];
                            final slotNumber = slot['slot_number'];
                            final isSelected = selectedSlotIds.contains(slotId);
                            final isBooked = slot['is_booked'] == true;
                            return GestureDetector(
                              onTap: isBooked
                                  ? null
                                  : () {
                                setState(() {
                                  if (isSelected) {
                                    selectedSlotIds.remove(slotId);
                                  } else {
                                    selectedSlotIds.add(slotId);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 65,
                                height: 65,
                                decoration: BoxDecoration(
                                  color: isBooked
                                      ? Colors.red[300]
                                      : isSelected
                                      ? const Color(0xFF4CAF50)
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: isSelected
                                      ? [
                                    BoxShadow(
                                      color: const Color(0xFF4CAF50).withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                      : [],
                                ),
                                child: Center(
                                  child: Text(
                                    "$slotNumber",
                                    style: TextStyle(
                                      color: isBooked || isSelected ? Colors.white : Colors.black,
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
                        backgroundColor: const Color(0xFF3F51B5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _startPayment, // Change here to call the payment function
                      child: Text(
                        "Pay and Confirm Booking (${selectedSlotIds.length * pricePerSlot})",
                        style: const TextStyle(
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
            color: const Color(0xFF3F51B5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF303030),
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
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSlotCount(IconData icon, String label, int available, int booked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$available / ${available + booked}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "$label (Avail/Total)",
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
