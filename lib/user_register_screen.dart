import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_login_screen.dart';

// --- THEME COLORS ---
// (Inverted to Light Mode)
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
  static const Color outlinedButtonColor = Color(0xFF8E8E93); // Kept
  static const Color elevatedButtonBg = Color(0xFF1C1C1E); // Was white

  static const Color shadow = Color.fromRGBO(0, 0, 0, 0.1); // Lighter shadow
  static const Color errorRed = Color(0xFFD32F2F); // (Kept)
}
// --- END THEME COLORS ---

class UserRegisterScreen extends StatefulWidget {
  const UserRegisterScreen({super.key});

  @override
  _UserRegisterScreenState createState() => _UserRegisterScreenState();
}

class _UserRegisterScreenState extends State<UserRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _carController = TextEditingController();
  final TextEditingController _bikeController = TextEditingController();
  bool _isLoading = false;
  String apiHost =
      'backend-parking-bk8y.onrender.com'; // Default for Android Emulator

  @override
  void initState() {
    super.initState();
    // Adjust host for web
    if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      apiHost = '127.0.0.1';
    }
  }

  Future<void> _registerUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      final userData = {
        'name': _nameController.text,
        'phone': _phoneController.text,
        'car_number_plate': _carController.text,
        'bike_number_plate': _bikeController.text,
      };

      try {
        final response = await http.post(
          Uri.parse('https://$apiHost/api/users/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(userData),
        );

        if (response.statusCode == 201) {
          _showSnackBar('Registration successful! Please log in.',
              isError: false);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const UserLoginScreen()),
            );
          }
        } else {
          final responseBody = jsonDecode(response.body);
          _showSnackBar('Registration failed: ${responseBody['message']}',
              isError: true);
        }
      } catch (e) {
        _showSnackBar('Error: $e', isError: true);
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        title: const Text("Register",
            style: TextStyle(color: AppColors.primaryText)),
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        iconTheme: const IconThemeData(
            color: AppColors.primaryText), // For back button
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Create Your Account",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildTextField(_nameController, "Name", Icons.person, (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              }),
              const SizedBox(height: 16),
              _buildTextField(_phoneController, "Phone Number", Icons.phone,
                  (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a phone number';
                }
                return null;
              }),
              const SizedBox(height: 16),
              _buildTextField(
                  _carController, "Car Number Plate", Icons.directions_car),
              const SizedBox(height: 16),
              _buildTextField(
                  _bikeController, "Bike Number Plate", Icons.motorcycle),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                      color: AppColors.primaryText,
                    ))
                  : ElevatedButton(
                      onPressed: _registerUser,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.elevatedButtonBg,
                        foregroundColor: AppColors.lightText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Register",
                          style: TextStyle(fontSize: 18)),
                    ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const UserLoginScreen()),
                  );
                },
                child: const Text(
                  "Already have an account? Login here.",
                  style: TextStyle(color: AppColors.markerColor), // Blue accent
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String labelText, IconData icon,
      [String? Function(String?)? validator]) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: AppColors.primaryText),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: AppColors.hintText),
        prefixIcon: Icon(icon, color: AppColors.hintText),
        filled: true,
        fillColor: AppColors.cardSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlinedButtonColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryText),
        ),
      ),
      validator: validator,
    );
  }
}
