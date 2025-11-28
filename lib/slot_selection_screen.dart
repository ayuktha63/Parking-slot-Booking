// slot_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'success_screen.dart';

import 'booking_screen.dart' hide AppColors; // for AppColors

class SlotSelectionScreen extends StatefulWidget {
  final String location;
  final String parkingId;
  final String phoneNumber;

  final String selectedVehicle;
  final String vehicleNumber;
  final DateTime startDate;
  final TimeOfDay startTime;

  const SlotSelectionScreen({
    super.key,
    required this.location,
    required this.parkingId,
    required this.phoneNumber,
    required this.selectedVehicle,
    required this.vehicleNumber,
    required this.startDate,
    required this.startTime,
  });

  @override
  State<SlotSelectionScreen> createState() => _SlotSelectionScreenState();
}

class _SlotSelectionScreenState extends State<SlotSelectionScreen> {
  late IO.Socket socket;
  late Razorpay _razorpay;

  String apiHost = "backend-parking-bk8y.onrender.com";
  String apiScheme = "https";

  List<dynamic> allSlots = [];
  Set<int> selectedSlotNumbers = {};
  bool isLoading = true;

  final double pricePerSlot = 30;

  @override
  void initState() {
    super.initState();

    if (kIsWeb &&
        (Uri.base.host == "localhost" || Uri.base.host == "127.0.0.1")) {
      apiHost = "127.0.0.1:3000";
      apiScheme = "http";
    }

    _initSocket();
    _initRazorpay();
    _fetchSlots();
  }

  // ---------------------------------------------------
  // SOCKET SETUP
  // ---------------------------------------------------
  void _initSocket() {
    socket = IO.io(
      "$apiScheme://$apiHost",
      IO.OptionBuilder().setTransports(['websocket']).build(),
    );

    socket.onConnect((_) {
      socket.emit("join_parking", {
        "parking_id": widget.parkingId,
        "vehicle_type": widget.selectedVehicle.toLowerCase(),
      });
    });

    socket.on("slot_update", (data) {
      final slotNum = data["slot_number"];
      final status = data["status"];
      final sameUser = data["phone"] == widget.phoneNumber;

      setState(() {
        allSlots = allSlots.map((x) {
          if (x["slot_number"] == slotNum) {
            return {...x, "status": status};
          }
          return x;
        }).toList();

        if (selectedSlotNumbers.contains(slotNum) &&
            !sameUser &&
            (status == "booked" || status == "held")) {
          selectedSlotNumbers.remove(slotNum);
        }
      });
    });

    socket.onDisconnect((_) {});
  }

  // ---------------------------------------------------
  // RAZORPAY
  // ---------------------------------------------------
  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _paymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _paymentError);
  }

  void _paymentSuccess(PaymentSuccessResponse response) {
    _confirmBooking(response.paymentId ?? "");
  }

  void _paymentError(PaymentFailureResponse response) {
    _showError("Payment Failed");
  }

  // ---------------------------------------------------
  // FETCH SLOTS
  // ---------------------------------------------------
  Future<void> _fetchSlots() async {
    setState(() => isLoading = true);

    final entryDateTime = DateTime(
      widget.startDate.year,
      widget.startDate.month,
      widget.startDate.day,
      widget.startTime.hour,
      widget.startTime.minute,
    );

    final url =
        "$apiScheme://$apiHost/api/parking_areas/${widget.parkingId}/slots"
        "?vehicle_type=${widget.selectedVehicle.toLowerCase()}"
        "&entry_time=${entryDateTime.toIso8601String()}";

    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      allSlots = jsonDecode(res.body);
    }

    setState(() => isLoading = false);
  }

  // ---------------------------------------------------
  // HOLD SLOT
  // ---------------------------------------------------
  Future<bool> _holdSlot(int slotNum) async {
    final url = "$apiScheme://$apiHost/api/holds";

    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "parking_id": int.parse(widget.parkingId),
        "slot_number": slotNum,
        "vehicle_type": widget.selectedVehicle.toLowerCase(),
        "phone": widget.phoneNumber,
      }),
    );

    return response.statusCode == 200;
  }

  // ---------------------------------------------------
  // START PAYMENT
  // ---------------------------------------------------
  void _startPayment() {
    if (selectedSlotNumbers.isEmpty) {
      _showError("Select at least one slot");
      return;
    }

    final amount = (selectedSlotNumbers.length * pricePerSlot * 100).toInt();

    var options = {
      'key': "rzp_live_R6QQALUuJwgDaD",
      'amount': amount,
      'name': "Parking Booking",
      'description': "Payment for selected slots",
      'prefill': {'contact': widget.phoneNumber},
    };

    _razorpay.open(options);
  }

  // ---------------------------------------------------
  // CONFIRM BOOKING
  // ---------------------------------------------------
  Future<void> _confirmBooking(String paymentId) async {
    final entryDateTime = DateTime(
      widget.startDate.year,
      widget.startDate.month,
      widget.startDate.day,
      widget.startTime.hour,
      widget.startTime.minute,
    );

    final List<int> bookedSlots = [];

    for (final slot in selectedSlotNumbers) {
      final url = "$apiScheme://$apiHost/api/bookings";

      final res = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "parking_id": int.parse(widget.parkingId),
          "slot_number": slot,
          "vehicle_type": widget.selectedVehicle.toLowerCase(),
          "number_plate": widget.vehicleNumber,
          "entry_time": entryDateTime.toIso8601String(),
          "phone": widget.phoneNumber,
          "payment_id": paymentId,
          "amount": (selectedSlotNumbers.length * pricePerSlot).toInt()
        }),
      );

      if (res.statusCode == 200) {
        bookedSlots.add(slot);
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SuccessScreen(
          location: widget.location,
          vehicleType: widget.selectedVehicle,
          slots: bookedSlots,
          entryDateTime: entryDateTime,
          phoneNumber: widget.phoneNumber,
        ),
      ),
    );
  }

  // ---------------------------------------------------
  // UI + LEGEND + SCROLL FIX
  // ---------------------------------------------------
  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: const Text("Error", style: TextStyle(color: Colors.white)),
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    socket.dispose();
    _razorpay.clear();
    super.dispose();
  }

  Widget _legend(Color color, String label) {
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
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.secondaryText)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        title: const Text("Select Slot"),
        backgroundColor: AppColors.appBarColor,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // LEGEND -----------------------------------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _legend(AppColors.infoItemBg, "Available"),
                        _legend(AppColors.markerColor, "Selected"),
                        _legend(Colors.orangeAccent, "Held"),
                        _legend(Colors.grey.shade600, "Booked"),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // SLOTS GRID --------------------------------------
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: allSlots.map((slot) {
                        final slotNum =
                            int.parse(slot["slot_number"].toString());
                        final status = slot["status"];

                        final isSelected =
                            selectedSlotNumbers.contains(slotNum);
                        final isBooked = status == "booked";
                        final isHeld = status == "held";

                        Color color;
                        if (isBooked) {
                          color = Colors.grey.shade700;
                        } else if (isHeld) {
                          color = Colors.orange;
                        } else if (isSelected) {
                          color = AppColors.markerColor;
                        } else {
                          color = AppColors.infoItemBg;
                        }

                        return GestureDetector(
                          onTap: (isBooked || isHeld)
                              ? null
                              : () async {
                                  if (isSelected) {
                                    selectedSlotNumbers.remove(slotNum);
                                    setState(() {});
                                    return;
                                  }

                                  final ok = await _holdSlot(slotNum);
                                  if (!ok) {
                                    _showError("Slot already taken");
                                    return;
                                  }

                                  selectedSlotNumbers.add(slotNum);
                                  setState(() {});
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 65,
                            height: 65,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "$slotNum",
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 30),

                    // BUTTON -----------------------------------
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _startPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.elevatedButtonBg,
                          foregroundColor: AppColors.darkText,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Book (${selectedSlotNumbers.length} slot · ₹${selectedSlotNumbers.length * pricePerSlot})",
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
