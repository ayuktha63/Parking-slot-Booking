import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:async'; // Added for Future.delayed

import 'success_screen.dart';
import 'booking_screen.dart' hide AppColors;

// ---------------- COLORS ----------------
class AppColors {
  static const background = Color(0xFFF7F7F9);
  static const cardBg = Color(0xFFFFFFFF);
  static const accent = Color(0xFF7B61FF);
  static const gold = Color(0xFFFCC417);
  static const subtleText = Color(0xFF9AA0A6);
  static const titleText = Color(0xFF222222);
  static const slotSelected = Color(0xFFDCE8FF);
  static const grid = Color(0xFFE2E2E2);
}

// ---------------- MAIN SCREEN ----------------
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
  final double price = 1;

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

  // ---------------- SOCKET ----------------
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
      if (!mounted) return;

      final slotNum = data["slot_number"];
      final status = data["status"];
      final sameUser = data["phone"] == widget.phoneNumber;

      setState(() {
        allSlots = allSlots.map((s) {
          if (s["slot_number"] == slotNum) {
            return {...s, "status": status};
          }
          return s;
        }).toList();

        if (selectedSlotNumbers.contains(slotNum) &&
            !sameUser &&
            (status == "booked" || status == "held")) {
          selectedSlotNumbers.remove(slotNum);
        }
      });
    });
  }

  // ---------------- PAYMENT ----------------
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

  // ---------------- FETCH SLOTS ----------------
  Future<void> _fetchSlots() async {
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

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        allSlots = jsonDecode(res.body);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  Future<bool> _holdSlot(int slotNum) async {
    try {
      final response = await http.post(
        Uri.parse("$apiScheme://$apiHost/api/holds"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "parking_id": int.parse(widget.parkingId),
          "slot_number": slotNum,
          "vehicle_type": widget.selectedVehicle.toLowerCase(),
          "phone": widget.phoneNumber,
        }),
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _startPayment() {
    if (selectedSlotNumbers.isEmpty) {
      _showError("Select a slot");
      return;
    }

    final amount = (selectedSlotNumbers.length * price * 100).toInt();

    _razorpay.open({
      'key': "rzp_live_R6QQALUuJwgDaD",
      'amount': amount,
      'name': "Parking Booking",
      'description': "Slot Booking",
      'prefill': {"contact": widget.phoneNumber},
    });
  }

  Future<void> _confirmBooking(String paymentId) async {
    final entryDateTime = DateTime(
      widget.startDate.year,
      widget.startDate.month,
      widget.startDate.day,
      widget.startTime.hour,
      widget.startTime.minute,
    );

    List<int> booked = [];

    for (final slot in selectedSlotNumbers) {
      final res = await http.post(
        Uri.parse("$apiScheme://$apiHost/api/bookings"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "parking_id": int.parse(widget.parkingId),
          "slot_number": slot,
          "vehicle_type": widget.selectedVehicle.toLowerCase(),
          "number_plate": widget.vehicleNumber,
          "entry_time": entryDateTime.toIso8601String(),
          "phone": widget.phoneNumber,
          "payment_id": paymentId,
          "amount": price.toInt()
        }),
      );

      if (res.statusCode == 200) {
        booked.add(slot);
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SuccessScreen(
          location: widget.location,
          vehicleType: widget.selectedVehicle,
          slots: booked,
          entryDateTime: entryDateTime,
          phoneNumber: widget.phoneNumber,
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  // ---------------- GRID UI HELPERS ----------------
  Map<String, List<Map<String, dynamic>>> _groupSlots() {
    final Map<String, List<Map<String, dynamic>>> lanes = {"A": [], "B": []};

    for (final s in allSlots) {
      final sn = int.tryParse(s["slot_number"].toString()) ?? 0;
      if (sn <= 6)
        lanes["A"]!.add(Map<String, dynamic>.from(s));
      else
        lanes["B"]!.add(Map<String, dynamic>.from(s));
    }

    lanes.forEach((k, v) => v.sort((a, b) {
          final aa = int.tryParse(a["slot_number"].toString()) ?? 0;
          final bb = int.tryParse(b["slot_number"].toString()) ?? 0;
          return aa.compareTo(bb);
        }));

    return lanes;
  }

  // PURE GRID + CARS (no tile boxes)
  Widget _gridForLane(String lane, List<Map<String, dynamic>> slots) {
    const columns = 3;
    const double cellHeight = 120;

    List<List<Map<String, dynamic>>> rows = [];
    for (int i = 0; i < slots.length; i += columns) {
      rows.add(slots.sublist(
          i, (i + columns > slots.length) ? slots.length : i + columns));
    }

    return Stack(
      children: [
        // Full dashed grid behind
        Positioned.fill(
          child: ParkingGridPainterWidget(columns: columns, rows: rows.length),
        ),

        // cars + labels
        Column(
          children: rows.map((row) {
            return SizedBox(
              height: cellHeight,
              child: Row(
                children: List.generate(columns, (i) {
                  if (i >= row.length) return Expanded(child: Container());

                  return Expanded(child: _slotCell(row[i], lane));
                }),
              ),
            );
          }).toList(),
        )
      ],
    );
  }

  Widget _slotCell(Map<String, dynamic> slot, String lane) {
    final int num = slot["slot_number"];
    final String status = slot["status"];

    final bool isBooked = status == "booked";
    final bool isHeld = status == "held";
    final bool isHeldByOtherUser =
        isHeld && slot["phone"] != widget.phoneNumber;

    // If YOU held the slot → treat as selected visually
    final bool isSelected = selectedSlotNumbers.contains(num) ||
        (isHeld && slot["phone"] == widget.phoneNumber);

    final bool isLocked = isBooked || isHeldByOtherUser;

    return GestureDetector(
      onTap: isLocked
          ? null
          : () async {
              if (isSelected) {
                // do NOT unselect if it's held by you — optional
                return;
              }

              bool ok = await _holdSlot(num);
              if (ok)
                setState(() => selectedSlotNumbers.add(num));
              else
                _showError("Unavailable");
            },
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.slotSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 8,
              bottom: 8,
              child: Text(
                "$lane-$num",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppColors.subtleText,
                ),
              ),
            ),

            // Booked + held by others → show car
            if (isBooked || isHeldByOtherUser)
              Center(
                child: SvgPicture.asset(
                  "assets/car.svg",
                  width: 40,
                  fit: BoxFit.contain,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // HEADER
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.arrow_back,
                              color: AppColors.titleText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Select Space",
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: AppColors.titleText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.location, // parking name
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: AppColors.subtleText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final lanes = _groupSlots();

                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              _gridForLane("A", lanes["A"] ?? []),
                              const SizedBox(height: 40),
                              Row(
                                children: [
                                  Expanded(
                                      child:
                                          Divider(color: AppColors.subtleText)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text("ENTRY",
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: AppColors.subtleText)),
                                  ),
                                  Expanded(
                                      child:
                                          Divider(color: AppColors.subtleText)),
                                ],
                              ),
                              const SizedBox(height: 40),
                              _gridForLane("B", lanes["B"] ?? []),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // ----------------------------------------------------
                  // CHANGED: REPLACED OLD BUTTON WITH NEW SLIDE BUTTON
                  // ----------------------------------------------------
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SlideActionBtn(
                      label: "Slide to Book",
                      baseColor: Colors.black, // Dark iOS style
                      knobColor: Colors.white,
                      successColor: AppColors.accent, // Uses your theme accent
                      onSubmit: () {
                        // Delay slightly to show visual success state before processing
                        Future.delayed(const Duration(milliseconds: 300), () {
                          _startPayment();
                        });
                      },
                    ),
                  )
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------
// NEW perfect GRID painter
// ---------------------------------------------------------
class ParkingGridPainterWidget extends StatelessWidget {
  final int columns;
  final int rows;

  const ParkingGridPainterWidget({
    super.key,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ParkingGridPainter(columns: columns, rows: rows),
    );
  }
}

class ParkingGridPainter extends CustomPainter {
  final int columns;
  final int rows;

  ParkingGridPainter({required this.columns, required this.rows});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.grid
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final double colW = size.width / columns;
    final double rowH = size.height / rows;

    // INTERNAL horizontal dashed lines only (skip top = 0 and bottom = rows)
    for (int r = 1; r < rows; r++) {
      double y = r * rowH;
      _dash(canvas, Offset(0, y), Offset(size.width, y), paint);
    }

    // Vertical dashed lines (keep all)
    for (int c = 1; c < columns; c++) {
      double x = c * colW;
      _dash(canvas, Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  void _dash(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dash = 6, gap = 6;
    final distance = (p2 - p1).distance;
    final dx = (p2.dx - p1.dx) / distance;
    final dy = (p2.dy - p1.dy) / distance;

    double drawn = 0;
    while (drawn < distance) {
      canvas.drawLine(
        Offset(p1.dx + dx * drawn, p1.dy + dy * drawn),
        Offset(p1.dx + dx * (drawn + dash), p1.dy + dy * (drawn + dash)),
        paint,
      );
      drawn += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------
// ADDED: iOS STYLE SLIDE-TO-ACTION WIDGET CLASS
// ---------------------------------------------------------
class SlideActionBtn extends StatefulWidget {
  final VoidCallback onSubmit;
  final String label;
  final Color baseColor;
  final Color knobColor;
  final Color successColor;

  const SlideActionBtn({
    super.key,
    required this.onSubmit,
    this.label = "Slide to Book",
    this.baseColor = Colors.black,
    this.knobColor = Colors.white,
    this.successColor = const Color(0xFF4CAF50),
  });

  @override
  State<SlideActionBtn> createState() => _SlideActionBtnState();
}

class _SlideActionBtnState extends State<SlideActionBtn>
    with SingleTickerProviderStateMixin {
  double _position = 0.0;
  bool _submitted = false;

  // To handle the snap-back animation
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (_submitted) return;
    // Stop any snap-back animation if the user grabs it again
    _controller.stop();
  }

  void _onDragUpdate(
      DragUpdateDetails details, double maxWidth, double knobWidth) {
    if (_submitted) return;

    final maxDrag = maxWidth - knobWidth;

    setState(() {
      // Move position, clamping between 0 and the end
      _position += details.delta.dx;
      if (_position < 0) _position = 0;
      if (_position > maxDrag) _position = maxDrag;
    });
  }

  void _onDragEnd(DragEndDetails details, double maxWidth, double knobWidth) {
    if (_submitted) return;

    final maxDrag = maxWidth - knobWidth;
    final threshold = maxDrag * 0.85; // Trigger if dragged 85% of the way

    if (_position > threshold) {
      // Success: Snap to end and trigger callback
      setState(() {
        _position = maxDrag;
        _submitted = true;
      });
      widget.onSubmit();
    } else {
      // Failure: Snap back to start using animation
      _animation = Tween<double>(begin: _position, end: 0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      )..addListener(() {
          setState(() {
            _position = _animation.value;
          });
        });
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64, // Standard iOS button height
      decoration: BoxDecoration(
        color: _submitted ? widget.successColor : widget.baseColor,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final knobSize = 56.0; // Slightly smaller than height for padding
          final padding = (64 - knobSize) / 2; // Vertical padding

          return Stack(
            children: [
              // 1. TEXT LABEL (Centered)
              Center(
                child: Opacity(
                  // Fade text out as slider moves over it
                  opacity:
                      (1 - (_position / (maxWidth - knobSize))).clamp(0.0, 1.0),
                  child: Text(
                    _submitted ? "SUCCESS" : widget.label,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // 2. DRAGGABLE KNOB
              Positioned(
                left: _position + padding,
                top: padding,
                child: GestureDetector(
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: (d) =>
                      _onDragUpdate(d, maxWidth, knobSize + (padding * 2)),
                  onHorizontalDragEnd: (d) =>
                      _onDragEnd(d, maxWidth, knobSize + (padding * 2)),
                  child: Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      color: widget.knobColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: Center(
                      child: _submitted
                          ? Icon(Icons.check,
                              color: widget.successColor, size: 28)
                          : Icon(Icons.chevron_right_rounded,
                              color: widget.baseColor, size: 32),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
