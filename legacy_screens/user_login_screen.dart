import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;

import 'home_screen.dart';
import 'user_register_screen.dart';

// ---------------- THEME ----------------
class AppColors {
  static const Color appBackground = Color(0xFFF5F7FA);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF000000);
  static const Color secondaryText = Color(0xFF555555);
  static const Color errorRed = Color(0xFFD32F2F);
}
// ---------------------------------------

// ============================================================================
//                                LOADING SCREEN
// ============================================================================
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
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      ),
    );
  }
}

// ============================================================================
//                          USER LOGIN SCREEN (UPDATED UI)
// ============================================================================
class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  _UserLoginScreenState createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  String apiHost = 'backend-parking-bk8y.onrender.com';
  String apiScheme = 'https';

  @override
  void initState() {
    super.initState();
    _setApiHost();
  }

  void _setApiHost() {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
        apiHost = '127.0.0.1:3000';
        apiScheme = 'http';
      }
    }
  }

  void _showMessage(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.black87,
      ),
    );
  }

  Future<bool> _registerOrLoginUser(String phone) async {
    try {
      final uri = Uri.parse('$apiScheme://$apiHost/api/users/register');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"phone": phone}),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      _showMessage("Server error: $e", error: true);
      return false;
    }
  }

  void _verifyPhone() async {
    String phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showMessage("Please enter your phone number", error: true);
      return;
    }

    setState(() => _isLoading = true);

    bool success = await _registerOrLoginUser(phone);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(phoneNumber: phone),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final h = size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------- TOP IMAGE ----------------
              SizedBox(
                height: h * 0.50,
                child: Stack(
                  children: [
                    Positioned.fill(
                      top: h * 0.12,
                      child: Image.asset(
                        "assets/login_car.png",
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      left: 24,
                      top: h * 0.09,
                      child: Text(
                        "PARQX",
                        style: GoogleFonts.montserrat(
                          fontSize: 60,
                          fontWeight: FontWeight.w700,
                          color: const Color.fromARGB(
                              255, 73, 73, 73), // ← UPDATED COLOR
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: h * 0.03),

              // ----------- TITLE TEXT (LEFT ALIGNED) -----------
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Start Parking",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: h * 0.005),
                    Text(
                      "Enter your phone number",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: h * 0.04),

              // ---------------- PHONE INPUT ----------------
// ---------------- PHONE INPUT ----------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      // --- STATIC COUNTRY CODE ---
                      Text(
                        "+91",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),

                      const SizedBox(width: 12),

                      Container(
                        width: 1.2,
                        height: 24,
                        color: Colors.grey[400],
                      ),

                      const SizedBox(width: 12),

                      // -------- INPUT FIELD --------
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            filled: true,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: "123456789",
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              vertical: size.height * 0.02,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: h * 0.04),

              // ---------------- LOGIN BUTTON ----------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: h * 0.065,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyPhone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF67009B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "Login",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),

              SizedBox(height: h * 0.02),

              // ---------------- SIGN UP ----------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UserRegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        "Sign up",
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF67009B),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: h * 0.03),
            ],
          ),
        ),
      ),
    );
  }
}
