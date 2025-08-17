import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_login_screen.dart';

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
          Uri.parse('http://localhost:3000/api/users/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(userData),
        );

        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful! Please log in.')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const UserLoginScreen()),
          );
        } else {
          final responseBody = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: ${responseBody['message']}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register"),
        backgroundColor: const Color(0xFF3F51B5),
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
                  color: const Color(0xFF303030),
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
              _buildTextField(_phoneController, "Phone Number", Icons.phone, (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a phone number';
                }
                return null;
              }),
              const SizedBox(height: 16),
              _buildTextField(_carController, "Car Number Plate", Icons.directions_car),
              const SizedBox(height: 16),
              _buildTextField(_bikeController, "Bike Number Plate", Icons.motorcycle),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _registerUser,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Register", style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const UserLoginScreen()),
                  );
                },
                child: const Text(
                  "Already have an account? Login here.",
                  style: TextStyle(color: Color(0xFF3F51B5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText, IconData icon, [String? Function(String?)? validator]) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator,
    );
  }
}