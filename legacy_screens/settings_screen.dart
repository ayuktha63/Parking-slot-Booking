import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'main_nav_screen.dart';

// ---- SHARED APP COLORS ----
class AppColors {
  static const Color background = Color(0xFFF7F7F9);
  static const Color cardBg = Colors.white;
  static const Color titleText = Color(0xFF222222);
  static const Color subtleText = Color(0xFF9AA0A6);
  static const Color accent = Color(0xFF7B61FF);
  static const Color shadow = Color.fromRGBO(33, 33, 33, 0.08);
  static const Color error = Color(0xFFD32F2F);
}

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
    if (kIsWeb) apiHost = '127.0.0.1';
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: error ? AppColors.error : AppColors.accent,
      ),
    );
  }

  Future<void> _updateName(String newName) async {
    try {
      final res = await http.put(
        Uri.parse("https://$apiHost/api/users/profile"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": widget.phoneNumber,
          "name": newName,
          "car_number_plate": _userData['car_number_plate'],
          "bike_number_plate": _userData['bike_number_plate'],
        }),
      );

      if (res.statusCode == 200) {
        setState(() => _userData['name'] = newName);
        _showSnack("Name updated successfully!");
      } else {
        _showSnack("Failed to update name", error: true);
      }
    } catch (e) {
      _showSnack(e.toString(), error: true);
    }
  }

  void _editNameDialog() {
    final controller = TextEditingController(text: _userData['name']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Edit Name",
          style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.titleText),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.poppins(color: AppColors.titleText),
          decoration: InputDecoration(
            labelText: "Name",
            labelStyle: GoogleFonts.poppins(color: AppColors.subtleText),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            child: Text("Cancel",
                style: GoogleFonts.poppins(color: AppColors.subtleText)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateName(controller.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("Save", style: GoogleFonts.poppins()),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Settings",
          style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.titleText),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.titleText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ---------- USER HEADER ----------
            Row(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.accent,
                  child:
                      const Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userData['name'],
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColors.titleText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.phoneNumber,
                      style: GoogleFonts.poppins(color: AppColors.subtleText),
                    ),
                  ],
                )
              ],
            ),

            const SizedBox(height: 28),

            _settingsTile(
              icon: Icons.person_outline,
              title: "Edit Name",
              onTap: _editNameDialog,
            ),
            const SizedBox(height: 12),

            _settingsTile(
              icon: Icons.phone_android_outlined,
              title: "Phone Number",
              onTap: () {
                _showSnack("Phone number cannot be changed", error: true);
              },
            ),
            const SizedBox(height: 12),

            _settingsTile(
              icon: Icons.privacy_tip_outlined,
              title: "Privacy Policy",
              onTap: () => _showSnack("Not implemented"),
            ),
            const SizedBox(height: 12),

            _settingsTile(
              icon: Icons.info_outline,
              title: "About",
              onTap: () => _showSnack("App v1.0.0"),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ---------------- UI COMPONENTS ----------------

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.accent),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppColors.titleText,
                  fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: AppColors.subtleText),
          ],
        ),
      ),
    );
  }
}
