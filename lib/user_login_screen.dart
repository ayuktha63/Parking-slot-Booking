import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_screen.dart';
import 'user_register_screen.dart'; // Import the register screen

// --- INVERTED THEME COLORS (LIGHT MODE) ---
class AppColors {
  static const Color appBackground = Color(0xFFF5F7FA); // Was dark
  static const Color cardSurface = Color(0xFFFFFFFF); // Was dark grey
  static const Color appBarColor = Color(0xFFF5F7FA); // Was dark
  static const Color infoItemBg = Color(0xFFE8E8E8); // Was dark grey

  static const Color primaryText = Color(0xFF000000); // Was white
  static const Color secondaryText = Color(0xFF555555); // Was light grey
  static const Color hintText = Color(0xFF8E8E93); // Kept as medium grey
  static const Color lightText = Color(0xFFFFFFFF); // Was dark (for buttons)

  static const Color markerColor = Color(0xFF0A84FF); // Blue accent (Kept)
  static const Color elevatedButtonBg = Color(0xFF1C1C1E); // Was white

  static const Color shadow = Color.fromRGBO(0, 0, 0, 0.1); // Lighter shadow
  static const Color errorRed = Color(0xFFD32F2F); // (Kept)
}
// --- END THEME COLORS ---

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserLoginScreen()),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/lottie/main_car.json',
              width: 250,
              height: 250,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 30),
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
              "Finding your parking spot...",
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  _UserLoginScreenState createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String apiHost = '10.0.2.2'; // Default for Android Emulator

  @override
  void initState() {
    super.initState();
    // Adjust host for web
    if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      apiHost = '127.0.0.1';
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
                color: isError ? AppColors.lightText : AppColors.primaryText),
          ),
          backgroundColor: isError ? AppColors.errorRed : AppColors.cardSurface,
        ),
      );
    }
  }

  Future<bool> _registerOrLoginUser(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('http://$apiHost:3000/api/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phoneNumber,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Successfully logged in or registered
        return true;
      } else {
        final body = jsonDecode(response.body);
        _showSnackBar('Login failed: ${body['message'] ?? 'Unknown error'}',
            isError: true);
        return false;
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
      return false;
    }
  }

  void _verifyPhone() async {
    setState(() => _isLoading = true);
    String phoneNumber = _phoneController.text.trim();

    bool success = await _registerOrLoginUser(phoneNumber);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        // Only navigate if login/register was successful
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(phoneNumber: phoneNumber),
          ),
        );
      }
      // If not successful, the snackbar was already shown by _registerOrLoginUser
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.appBackground, // Use solid light background
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                Lottie.asset(
                  'assets/lottie/parking_animation.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  "Welcome to ParkEasy",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  "Book your parking spot in seconds",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_parking_rounded,
                            color: AppColors.markerColor, // Blue accent
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Start Parking",
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Enter your phone number to begin",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: AppColors.primaryText,
                        ),
                        decoration: InputDecoration(
                          hintText: "+91 123 456 7890",
                          hintStyle:
                              GoogleFonts.poppins(color: AppColors.hintText),
                          prefixIcon: Icon(Icons.phone_rounded,
                              color: AppColors.markerColor),
                          filled: true,
                          fillColor: AppColors.infoItemBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyPhone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.elevatedButtonBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: AppColors.lightText)
                        : Text(
                            "Login",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.lightText,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const UserRegisterScreen()),
                    );
                  },
                  child: const Text(
                    "Don't have an account? Register here.",
                    style: TextStyle(color: AppColors.markerColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
