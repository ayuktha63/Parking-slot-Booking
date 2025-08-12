import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'success_screen.dart';
import 'dart:async';

class SuccessAnimationScreen extends StatefulWidget {
  final String location;
  final String vehicleType;
  final List<int> slots;
  final DateTime entryDateTime;
  final DateTime exitDateTime;

  const SuccessAnimationScreen({
    required this.location,
    required this.vehicleType,
    required this.slots,
    required this.entryDateTime,
    required this.exitDateTime,
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
    // The navigation logic is handled by the onLoaded callback in the build method.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/success.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              repeat: false,
              onLoaded: (composition) {
                Future.delayed(
                  composition.duration + const Duration(seconds: 1),
                      () {
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SuccessScreen(
                            location: widget.location,
                            vehicleType: widget.vehicleType,
                            slots: widget.slots,
                            entryDateTime: widget.entryDateTime,
                            exitDateTime: widget.exitDateTime,
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
