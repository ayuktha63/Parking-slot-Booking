import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'main_nav_screen.dart';
import 'my_bookings_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

// ---- SHARED APP COLORS (LIGHT THEME) ----
class AppColors {
  static const Color background = Color(0xFFF7F7F9);
  static const Color cardBg = Colors.white;
  static const Color titleText = Color(0xFF222222);
  static const Color subtleText = Color(0xFF9AA0A6);
  static const Color accent = Color(0xFF7B61FF);
  static const Color shadow = Color.fromRGBO(33, 33, 33, 0.08);
}

class ProfileScreen extends StatefulWidget {
  final String phoneNumber;

  const ProfileScreen({super.key, required this.phoneNumber});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  int navIndex = 3; // Profile Tab Highlight
  String apiHost = "backend-parking-bk8y.onrender.com";

  @override
  void initState() {
    super.initState();
    if (kIsWeb) apiHost = "127.0.0.1";
    _fetchUserData();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await http.get(
        Uri.parse("https://$apiHost/api/users/profile/${widget.phoneNumber}"),
      );

      if (response.statusCode == 200) {
        setState(() {
          _userData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        _showError("Failed to fetch user data");
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _logout() {
    Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
  }

  // ---------------- NAV BAR HANDLER ----------------
  void _onNavTap(int index) {
    if (index == navIndex) return;

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(phoneNumber: widget.phoneNumber),
        ),
      );
    } else if (index == 1) {
      // Map not added yet
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MyBookingsScreen(phoneNumber: widget.phoneNumber),
        ),
      );
    } else if (index == 3) {
      // Already here
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------------- HEADER ----------------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _userData?['name'] ?? "User",
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: AppColors.titleText,
                          ),
                        ),
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.accent,
                          child: const Icon(Icons.person,
                              color: Colors.white, size: 30),
                        )
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ---------------- PERSONAL CARD ----------------
                    _profileCard(
                      icon: Icons.person_outline,
                      title: "Personal Details",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              phoneNumber: widget.phoneNumber,
                              initialUserData: _userData!,
                            ),
                          ),
                        ).then((_) => _fetchUserData());
                      },
                    ),

                    const SizedBox(height: 20),

                    // ---------------- 3 SQUARE BOXES ----------------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _squareBox(Icons.help_outline, "Help"),
                        _squareBox(
                            Icons.account_balance_wallet_outlined, "Wallet"),
                        _squareBox(Icons.inbox_outlined, "Inbox"),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // ---------------- LOGOUT BUTTON ----------------
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text("Logout",
                            style: GoogleFonts.poppins(fontSize: 16)),
                      ),
                    ),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
      ),

      // ---------------- NEW NAV BAR ----------------
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: MainNavBar(
          currentIndex: navIndex,
          onItemSelected: _onNavTap,
        ),
      ),
    );
  }

  // ------------------ WIDGETS ------------------

  Widget _squareBox(IconData icon, String label) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: AppColors.titleText),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppColors.subtleText)),
        ],
      ),
    );
  }

  Widget _profileCard(
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 26, color: AppColors.accent),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.titleText,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: AppColors.subtleText),
          ],
        ),
      ),
    );
  }
}
