import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform; // Import for platform check

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
  // Production/Default Host
  String apiHost = 'backend-parking-bk8y.onrender.com';
  String apiScheme = 'https';

  @override
  void initState() {
    super.initState();
    _setApiHost();
  }

  // Helper to determine the correct host based on environment
  void _setApiHost() {
    // Check if running in a development environment (emulator/local web)
    // Note: Checking for 'localhost' or '127.0.0.1' in web is usually enough.
    // For Android emulator pointing to local host, '10.0.2.2' is the correct IP.
    if (Platform.isAndroid || Platform.isIOS) {
      // If you are using a local server on your machine for testing the app on a physical device or simulator
      // apiHost = 'YOUR_LOCAL_IP_ADDRESS:3000'; // e.g., '192.168.1.10:3000'
      // apiScheme = 'http';
    } else if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      apiHost = '127.0.0.1:3000'; // Assuming local server runs on port 3000
      apiScheme = 'http';
    }
    // If not local, it defaults to the production 'backend-parking-bk8y.onrender.com' over 'https'
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

  // Updated to use the combined /api/users/register endpoint for login/registration check
  Future<bool> _registerOrLoginUser(String phoneNumber) async {
    try {
      final uri = Uri.parse('$apiScheme://$apiHost/api/users/register');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phoneNumber,
            }),
          )
          .timeout(const Duration(seconds: 15)); // Add timeout for reliability

      // Status 200 (OK) = User already exists (Login)
      // Status 201 (Created) = New user registered
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final message = body['message'];

        // Show a helpful message to the user
        _showSnackBar(message.contains('exists')
            ? 'Login successful!'
            : 'Registration successful!');
        return true;
      } else {
        final body = jsonDecode(response.body);
        _showSnackBar(
            'Authentication failed: ${body['message'] ?? 'Unknown error'}',
            isError: true);
        return false;
      }
    } on TimeoutException {
      _showSnackBar(
          'Connection timed out. Check your network or server status.',
          isError: true);
      return false;
    } catch (e) {
      _showSnackBar('Error connecting to the server: ${e.toString()}',
          isError: true);
      return false;
    }
  }

  void _verifyPhone() async {
    String phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      _showSnackBar('Please enter your phone number.', isError: true);
      return;
    }

    // Simple validation (can be more robust)
    if (phoneNumber.length < 10) {
      _showSnackBar('Phone number seems too short.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    bool success = await _registerOrLoginUser(phoneNumber);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        // Navigate to HomeScreen with the phone number
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(phoneNumber: phoneNumber),
          ),
        );
      }
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
                        maxLength: 15, // Set max length for phone number
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: AppColors.primaryText,
                        ),
                        decoration: InputDecoration(
                          hintText: "+91 123 456 7890",
                          counterText: "", // Hide the counter
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
                    // Navigate to the User Register Screen
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
