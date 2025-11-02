import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'user_register_screen.dart';
import 'dart:async';

// --- THEME COLORS ---
class AppColors {
  static const Color appBackground = Color(0xFF1C1C1E);
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB0B0B5);
}
// --- END THEME COLORS ---

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserRegisterScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // This is the Lottie animation
            Lottie.asset(
              'assets/lottie/loading_animation.json',
              width: 300,
              height: 300,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              "ParkEasy",
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Finding parking spots near you...",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
