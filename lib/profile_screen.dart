import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'my_bookings_screen.dart';
import 'user_register_screen.dart'; // Import the new registration screen
import 'package:flutter/foundation.dart' show kIsWeb;

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
  static const Color errorRed = Color(0xFFD32F2F); // A dark red for errors
}
// --- END THEME COLORS ---

class ProfileScreen extends StatefulWidget {
  final String phoneNumber;

  const ProfileScreen({super.key, required this.phoneNumber});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String apiHost = '10.0.2.2';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      apiHost = '127.0.0.1';
    }
    _fetchUserData();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: AppColors.primaryText),
          ),
          backgroundColor: isError ? AppColors.errorRed : AppColors.cardSurface,
        ),
      );
    }
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse(
            'http://$apiHost:3000/api/users/profile/${widget.phoneNumber}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _userData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        _showSnackBar('Failed to load user data: ${response.statusCode}',
            isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showSnackBar('Error fetching user data: $e', isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile(
      String name, String carNumber, String bikeNumber) async {
    try {
      final response = await http.put(
        Uri.parse('http://$apiHost:3000/api/users/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': widget.phoneNumber,
          'name': name,
          'car_number_plate': carNumber,
          'bike_number_plate': bikeNumber,
        }),
      );
      if (response.statusCode == 200) {
        _fetchUserData();
        _showSnackBar('Profile updated successfully!', isError: false);
      } else {
        final responseBody = jsonDecode(response.body);
        _showSnackBar('Failed to update profile: ${responseBody['message']}',
            isError: true);
      }
    } catch (e) {
      _showSnackBar('Error updating profile: $e', isError: true);
    }
  }

  void _buildEditProfileDialog() {
    final TextEditingController nameController =
        TextEditingController(text: _userData?['name']);
    final TextEditingController carController =
        TextEditingController(text: _userData?['car_number_plate']);
    final TextEditingController bikeController =
        TextEditingController(text: _userData?['bike_number_plate']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardSurface,
          title: const Text('Edit Profile',
              style: TextStyle(color: AppColors.primaryText)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(nameController, 'Name'),
                const SizedBox(height: 16),
                _buildDialogTextField(carController, 'Car Number Plate'),
                const SizedBox(height: 16),
                _buildDialogTextField(bikeController, 'Bike Number Plate'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.markerColor)),
            ),
            ElevatedButton(
              onPressed: () {
                _updateProfile(nameController.text, carController.text,
                    bikeController.text);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.elevatedButtonBg,
                foregroundColor: AppColors.darkText,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Helper for dialog text fields
  Widget _buildDialogTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.primaryText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.hintText),
        filled: true,
        fillColor: AppColors.infoItemBg,
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
    );
  }

  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (context) =>
              const UserRegisterScreen()), // Navigate to the registration screen
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        title: Text(
          "Profile",
          style: GoogleFonts.poppins(color: AppColors.primaryText),
        ),
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.primaryText),
            onPressed: _isLoading ? null : _buildEditProfileDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryText))
          : _userData == null
              ? const Center(
                  child: Text("User data not found.",
                      style: TextStyle(color: AppColors.secondaryText)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.markerColor,
                        child: Icon(Icons.person,
                            size: 60, color: AppColors.primaryText),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _userData!['name'] ?? 'Guest',
                        style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _userData!['phone'] ?? 'N/A',
                        style: GoogleFonts.poppins(
                            fontSize: 16, color: AppColors.secondaryText),
                      ),
                      const SizedBox(height: 30),
                      _buildInfoCard(
                        icon: Icons.directions_car,
                        title: "Car Number Plate",
                        value: _userData!['car_number_plate'] ?? 'Not set',
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        icon: Icons.motorcycle,
                        title: "Bike Number Plate",
                        value: _userData!['bike_number_plate'] ?? 'Not set',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MyBookingsScreen(
                                    phoneNumber: widget.phoneNumber),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history,
                              color: AppColors.darkText),
                          label: Text(
                            "My Bookings",
                            style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: AppColors.darkText,
                                fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.elevatedButtonBg,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => _logout(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.errorRed,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 5,
                          ),
                          child: Text(
                            "Logout",
                            style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: AppColors.primaryText,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      color: AppColors.cardSurface,
      elevation: 4,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: AppColors.markerColor),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppColors.secondaryText),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
