// main_file.dart
// NOTE: This file now contains both screens.
// In a real app, you would split SettingsScreen into its own file.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:parking_booking/user_login_screen.dart';
import 'dart:convert';
import 'user_register_screen.dart'; // Import the registration screen
import 'my_bookings_screen.dart'; // ADDED: Placeholder for your bookings screen
import 'package:flutter/foundation.dart' show kIsWeb;

// --- THEME COLORS ---
// (AppColors remains the same, but I'm including it here
// so the SettingsScreen can use it too)
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

// --- NEW SETTINGS SCREEN ---
// (This would normally be in 'settings_screen.dart')

class SettingsScreen extends StatefulWidget {
  final String phoneNumber;
  final Map<String, dynamic> initialUserData;

  const SettingsScreen({
    super.key,
    required this.phoneNumber,
    required this.initialUserData,
  });

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Map<String, dynamic> _userData;
  String apiHost = 'backend-parking-bk8y.onrender.com';

  @override
  void initState() {
    super.initState();
    _userData = widget.initialUserData;
    if (kIsWeb) {
      apiHost = '127.0.0.1';
    }
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

  // Updated function to only update the name
  Future<void> _updateName(String name) async {
    try {
      final response = await http.put(
        Uri.parse('https://$apiHost/api/users/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': widget.phoneNumber,
          'name': name,
          // Sending existing values for other fields if API requires them
          'car_number_plate': _userData['car_number_plate'],
          'bike_number_plate': _userData['bike_number_plate'],
        }),
      );
      if (response.statusCode == 200) {
        // Update local state to reflect change immediately
        setState(() {
          _userData['name'] = name;
        });
        _showSnackBar('Name updated successfully!', isError: false);
      } else {
        final responseBody = jsonDecode(response.body);
        _showSnackBar('Failed to update name: ${responseBody['message']}',
            isError: true);
      }
    } catch (e) {
      _showSnackBar('Error updating name: $e', isError: true);
    }
  }

  // Dialog to edit the name
  void _buildEditNameDialog() {
    final TextEditingController nameController =
        TextEditingController(text: _userData['name']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardSurface,
          title: const Text('Edit Name',
              style: TextStyle(color: AppColors.primaryText)),
          content: _buildDialogTextField(nameController, 'Name'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.markerColor)),
            ),
            ElevatedButton(
              onPressed: () {
                _updateName(nameController.text);
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

  // Helper for dialog text fields (copied from original ProfileScreen)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        title: Text(
          "Settings",
          style: GoogleFonts.poppins(color: AppColors.primaryText),
        ),
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.primaryText, // Controls back arrow color
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: AppColors.markerColor,
                  child: Icon(Icons.person,
                      size: 35, color: AppColors.primaryText),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userData['name'] ?? 'Guest',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userData['phone'] ?? 'N/A',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.cardSurface, thickness: 2),
            const SizedBox(height: 16),

            // Settings Items
            _buildSettingsItem(
              icon: Icons.edit_outlined,
              title: "Edit Name",
              onTap: _buildEditNameDialog,
            ),
            const SizedBox(height: 12),
            _buildSettingsItem(
              icon: Icons.phone_outlined,
              title: "Edit Phone Number",
              onTap: () {
                // Changing phone number is complex (needs verification)
                _showSnackBar("Phone number cannot be changed at this time.",
                    isError: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for settings list items
  Widget _buildSettingsItem(
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.markerColor, size: 24),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppColors.primaryText,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios,
                color: AppColors.hintText, size: 16),
          ],
        ),
      ),
    );
  }
}
// --- END NEW SETTINGS SCREEN ---

// --- MODIFIED PROFILE SCREEN ---

class ProfileScreen extends StatefulWidget {
  final String phoneNumber;

  const ProfileScreen({super.key, required this.phoneNumber});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String apiHost = 'backend-parking-bk8y.onrender.com';

  // ADDED: State for BottomNavBar
  int _bottomNavIndex = 2; // Profile is the 3rd item (index 2)

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
        Uri.parse('https://$apiHost/api/users/profile/${widget.phoneNumber}'),
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

  // NOTE: All update/edit logic has been moved to SettingsScreen

  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (context) =>
              const UserLoginScreen()), // Navigate to the login screen
      (route) => false,
    );
  }

  void _navigateToSettings() {
    if (_userData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SettingsScreen(
            phoneNumber: widget.phoneNumber,
            initialUserData: _userData!,
          ),
        ),
      ).then((_) {
        // After returning from settings, refresh user data
        // in case the name was changed
        _fetchUserData();
      });
    } else {
      _showSnackBar("User data not loaded yet.", isError: true);
    }
  }

  // --- REPLACED ---
  /// Handles navigation for the bottom bar
  void _onBottomNavItemTapped(int index) {
    if (index == 0) {
      // Current screen (Map), do nothing
      // NOTE: This logic seems to be from the Home screen.
      // On Profile screen, index 0 should probably navigate home.
      // Keeping user's provided logic.
      Navigator.of(context)
          .popUntil((route) => route.isFirst); // Go back to home
      return;
    }

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MyBookingsScreen(phoneNumber: widget.phoneNumber),
        ),
      ).then((_) {
        // When returning from profile, reset index to 0 (Map)
        if (mounted) {
          // This logic is a bit unusual for the Profile screen itself
          // It might be better to pop and set the index on the *previous* screen.
          // For now, just setting this screen's index.
          setState(() => _bottomNavIndex = 2); // Reset to Profile
        }
      });
    }

    if (index == 2) {
      // Navigate to Profile - ALREADY HERE
      // Do nothing
      return;
    }

    // Set the state to visually update the bar
    setState(() {
      _bottomNavIndex = index;
    });
  }
  // --- END REPLACED ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      // No AppBar, header is built into the body
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryText))
            : _userData == null
                ? const Center(
                    child: Text("User data not found.",
                        style: TextStyle(color: AppColors.secondaryText)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // New Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _userData!['name'] ?? 'Guest',
                              style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryText),
                            ),
                            const CircleAvatar(
                              radius: 30, // Smaller circle
                              backgroundColor: AppColors.markerColor,
                              child: Icon(Icons.person,
                                  size: 30, color: AppColors.primaryText),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Personal Card
                        _buildPersonalCard(),
                        const SizedBox(height: 30),

                        // 3 Square Boxes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSquareBox(
                                icon: Icons.help_outline,
                                label: "Help",
                                onTap: () {
                                  // TODO: Navigate to Help page
                                  _showSnackBar("Help page not implemented.");
                                }),
                            _buildSquareBox(
                                icon: Icons.account_balance_wallet_outlined,
                                label: "Wallet",
                                onTap: () {
                                  // TODO: Navigate to Wallet page
                                  _showSnackBar("Wallet page not implemented.");
                                }),
                            _buildSquareBox(
                                icon: Icons.inbox_outlined,
                                label: "Inbox",
                                onTap: () {
                                  // TODO: Navigate to Inbox page
                                  _showSnackBar("Inbox page not implemented.");
                                }),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Settings Button
                        _buildSettingsButton(),

                        const SizedBox(height: 20),

                        // Logout Button
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

                        // --- ADDED "Orque" TEXT ---
                        const SizedBox(
                            height: 40), // Add spacing to push it down
                        Text(
                          "ORQUE INNOVATIONS LLP ❤️",
                          style: GoogleFonts.poppins(
                            fontSize: 40, // Larger font
                            fontWeight: FontWeight.w600,
                            color: AppColors.hintText, // Grey shade
                          ),
                        ),
                        const SizedBox(
                            height:
                                20), // Padding at the very bottom of the scroll
                        // --- END ADDED TEXT ---
                      ],
                    ),
                  ),
      ),
      // ADDED: The new Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.appBarColor, // Match app bar
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_filled_rounded),
            activeIcon: Icon(Icons.directions_car_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_parking_outlined),
            activeIcon: Icon(Icons.local_parking_rounded),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle_rounded),
            label: 'Profile',
          ),
        ],
        currentIndex: _bottomNavIndex,
        selectedItemColor: AppColors.primaryText, // Active icon color
        unselectedItemColor: AppColors.hintText, // Inactive icon color
        onTap: _onBottomNavItemTapped,
        type: BottomNavigationBarType.fixed, // Keeps all visible
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w400),
      ),
    );
  }

  // New helper widget for the "Personal" card
  Widget _buildPersonalCard() {
    return Card(
      color: AppColors.cardSurface,
      elevation: 4,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _navigateToSettings,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // --- MODIFIED (was hardcoded white) ---
              const Icon(Icons.person_outline, color: AppColors.primaryText),
              const SizedBox(width: 16),
              Text(
                "Personal",
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios,
                  color: AppColors.hintText, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // New helper widget for the 3 square boxes
  Widget _buildSquareBox(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primaryText, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                  color: AppColors.secondaryText, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // New helper widget for the "Settings" button
  Widget _buildSettingsButton() {
    return InkWell(
      onTap: _navigateToSettings,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // --- MODIFIED (was hardcoded white) ---
            const Icon(Icons.settings_outlined, color: AppColors.primaryText),
            const SizedBox(width: 16),
            Text(
              "Settings",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppColors.primaryText,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios,
                color: AppColors.hintText, size: 16),
          ],
        ),
      ),
    );
  }

  // This widget is no longer used
  /*
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    // ... (code removed)
  }
  */
}
