import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'success_screen.dart';

class SuccessAnimationScreen extends StatefulWidget {
  final String location;
  final DateTime date;
  final TimeOfDay time;
  final String vehicleType;
  final List<int> slots;

  const SuccessAnimationScreen({
    required this.location,
    required this.date,
    required this.time,
    required this.vehicleType,
    required this.slots,
    super.key,
  });

  @override
  State<SuccessAnimationScreen> createState() => _SuccessAnimationScreenState();
}

class _SuccessAnimationScreenState extends State<SuccessAnimationScreen>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    // Navigate to SuccessScreen after animation completes + 1 second delay
    Future.delayed(const Duration(milliseconds: 2500), () {
      // Assuming animation duration is ~2 seconds; adjust if needed
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SuccessScreen(
                location: widget.location,
                date: widget.date,
                time: widget.time,
                vehicleType: widget.vehicleType,
                slots: widget.slots,
              ),
            ),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Match your app’s theme
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/success.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              repeat: false, // Play once
              onLoaded: (composition) {
                // Optional: Adjust delay based on actual animation duration
                Future.delayed(
                    composition.duration + const Duration(seconds: 1), () {
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SuccessScreen(
                          location: widget.location,
                          date: widget.date,
                          time: widget.time,
                          vehicleType: widget.vehicleType,
                          slots: widget.slots,
                        ),
                      ),
                    );
                  }
                });
              },
            ),
            const SizedBox(height: 20),
            const Text(
              "Booking Confirmed!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3F51B5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
