import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'success_screen.dart';

class SuccessAnimationScreen extends StatefulWidget {
  final String location;
  final DateTime date; // Legacy, kept for compatibility
  final TimeOfDay time; // Legacy, kept for compatibility
  final String vehicleType;
  final List<int> slots;
  final DateTime entryDateTime; // New: Full entry date and time
  final DateTime exitDateTime; // New: Full exit date and time

  const SuccessAnimationScreen({
    required this.location,
    required this.date,
    required this.time,
    required this.vehicleType,
    required this.slots,
    required this.entryDateTime, // Added
    required this.exitDateTime, // Added
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
    // No navigation here; handled in onLoaded callback
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
                // Navigate after animation duration + 1 second delay
                Future.delayed(
                  composition.duration + const Duration(seconds: 1),
                  () {
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
                            entryDateTime:
                                widget.entryDateTime, // Pass new param
                            exitDateTime: widget.exitDateTime, // Pass new param
                          ),
                        ),
                      );
                    }
                  },
                );
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
