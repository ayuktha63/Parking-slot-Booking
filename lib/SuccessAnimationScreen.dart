import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'success_screen.dart';
import 'dart:async';

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

  static const Color markerColor = Color(0xFF0A84FF); // Blue accent
  static const Color routeColor = Color(0xFF5AC8FA);
  static const Color outlinedButtonColor = Color(0xFF8E8E93);
  static const Color elevatedButtonBg = Color(0xFFFFFFFF);

  static const Color shadow = Color.fromRGBO(0, 0, 0, 0.3);
  static const Color successGreen = Color(0xFF34C759); // iOS-like success green
}
// --- END THEME COLORS ---

class SuccessAnimationScreen extends StatefulWidget {
  final String location;
  final String vehicleType;
  final List<int> slots;
  final DateTime entryDateTime;
  final String phoneNumber;

  const SuccessAnimationScreen({
    required this.location,
    required this.vehicleType,
    required this.slots,
    required this.entryDateTime,
    required this.phoneNumber,
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
      backgroundColor: AppColors.appBackground,
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
                            phoneNumber: widget.phoneNumber,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              "Booking Confirmed!",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.successGreen, // Use success color
              ),
            ),
          ],
        ),
      ),
    );
  }
}
