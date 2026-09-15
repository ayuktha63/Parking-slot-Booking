import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'home_screen.dart';
import 'profile_screen.dart';
import 'main_nav_screen.dart';
import 'package:parking_booking/main.dart'; // for pushSmooth()

// --- THEME COLORS (Matched to HomeScreen) ---
class AppColors {
  static const Color background = Color(0xFFF7F7F9);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color subtleText = Color(0xFF9AA0A6);
  static const Color titleText = Color(0xFF222222);
  static const Color accent = Color(0xFF67009B);
  static const Color glassBg = Color.fromRGBO(255, 255, 255, 0.15);
  static const Color shadow = Color.fromRGBO(33, 33, 33, 0.08);
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color cancelledGrey = Color(0xFFD32F2F);
}
// --- END THEME COLORS ---

class MyBookingsScreen extends StatefulWidget {
  final String phoneNumber;

  const MyBookingsScreen({super.key, required this.phoneNumber});

  @override
  _MyBookingsScreenState createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<dynamic> _bookings = [];
  bool _isLoading = true;
  String apiHost = 'backend-parking-bk8y.onrender.com';
  String apiScheme = 'https';

  int _currentTab = 0; // 0 = Active, 1 = Completed, 2 = Cancelled

  @override
  void initState() {
    super.initState();
    _setApiHost();
    _fetchMyBookings();
  }

  void _setApiHost() {
    if (kIsWeb &&
        (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1')) {
      apiHost = '127.0.0.1:3000';
      apiScheme = 'http';
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(message, style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _fetchMyBookings() async {
    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(
          '$apiScheme://$apiHost/api/users/bookings/${widget.phoneNumber}');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        setState(() {
          _bookings = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        _showErrorSnackBar('Failed to load bookings');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching bookings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelBooking(dynamic booking) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Cancel Booking?",
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: AppColors.titleText),
        ),
        content: Text(
          "Do you really want to cancel this booking?",
          style: GoogleFonts.poppins(color: AppColors.subtleText),
        ),
        actions: [
          TextButton(
            child: Text("No",
                style: GoogleFonts.poppins(color: AppColors.subtleText)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: Text("Yes",
                style: GoogleFonts.poppins(
                    color: AppColors.errorRed, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final uri = Uri.parse('$apiScheme://$apiHost/api/bookings/cancel');

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "booking_id": booking["id"],
          "parking_id": booking["parking_id"],
          "vehicle_type": booking["vehicle_type"]
        }),
      );

      if (response.statusCode == 200) {
        _showErrorSnackBar("Booking Cancelled");
        _fetchMyBookings();
      } else {
        _showErrorSnackBar("Failed to cancel booking");
      }
    } catch (e) {
      _showErrorSnackBar("Error: $e");
    }
  }

// NEW iOS Sliding Segmented Control
  Widget _buildTopTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Stack(
              children: [
                // 🔵 Sliding Purple Background
                AnimatedAlign(
                  alignment: _currentTab == 0
                      ? Alignment.centerLeft
                      : _currentTab == 1
                          ? Alignment.center
                          : Alignment.centerRight,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 32) / 3,
                    height: 44,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                  ),
                ),

                // TAB LABELS
                Row(
                  children: [
                    _tabLabel("Active", 0),
                    _tabLabel("Completed", 1),
                    _tabLabel("Cancelled", 2),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabLabel(String text, int index) {
    final active = _currentTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.titleText,
            ),
            child: Text(text),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String text, int index) {
    final active = _currentTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: active ? Colors.white : AppColors.titleText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // FILTER BOOKINGS
    final filtered = _bookings.where((b) {
      final isCancelled = b['cancelled'] == true;
      final isCompleted = !isCancelled &&
          (b['exit_time'] != null || (b['status'] ?? 'active') == 'completed');

      if (_currentTab == 0) return !isCancelled && !isCompleted; // Active
      if (_currentTab == 1) return isCompleted; // Completed
      if (_currentTab == 2) return isCancelled; // Cancelled

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "My Bookings",
          style: GoogleFonts.poppins(
              color: AppColors.titleText, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.titleText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopTabs(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.accent))
                    : filtered.isEmpty
                        ? _emptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) =>
                                _buildBookingCard(filtered[index]),
                          ),
              ),
            ],
          ),

          // ---- NAVBAR ----
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: MainNavBar(
              currentIndex: 2,
              onItemSelected: (index) {
                if (index == 0) {
                  pushSmooth(
                    context,
                    HomeScreen(phoneNumber: widget.phoneNumber),
                  );
                } else if (index == 3) {
                  pushSmooth(
                    context,
                    ProfileScreen(phoneNumber: widget.phoneNumber),
                  );
                }
              },
              centerIcon: Icons.refresh_rounded,
              centerAction: () => _fetchMyBookings(),
            ),
          ),
        ],
      ),
    );
  }

  // -------- Empty State --------
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(
            "No bookings found.",
            style:
                GoogleFonts.poppins(fontSize: 18, color: AppColors.subtleText),
          ),
        ],
      ),
    );
  }

  // -------- Booking Card --------
  Widget _buildBookingCard(dynamic booking) {
    final entryTime = DateTime.parse(booking['entry_time']);
    final bool isCancelled = booking['cancelled'] == true;
    final bool isCompleted = !isCancelled &&
        (booking['exit_time'] != null ||
            (booking['status'] ?? 'active') == 'completed');

    String statusText = "Active";
    Color statusColor = AppColors.accent;
    Color statusBg = AppColors.accent.withOpacity(0.1);

    if (isCancelled) {
      statusText = "Cancelled";
      statusColor = AppColors.cancelledGrey;
      statusBg = Colors.grey.withOpacity(0.1);
    } else if (isCompleted) {
      statusText = "Completed";
      statusColor = AppColors.successGreen;
      statusBg = Colors.green.withOpacity(0.1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking['location'] ?? 'Unknown Location',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.titleText),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.poppins(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 20, color: Color(0xFFEEEEEE)),

            _buildDetailRow(Icons.calendar_today, "Date",
                DateFormat('MMM dd, yyyy').format(entryTime)),
            _buildDetailRow(Icons.access_time, "Entry",
                DateFormat('hh:mm a').format(entryTime)),

            if (isCancelled)
              _buildDetailRow(
                Icons.cancel_outlined,
                "Cancelled",
                booking['cancelled_at'] != null
                    ? DateFormat('hh:mm a')
                        .format(DateTime.parse(booking['cancelled_at']))
                    : '-',
              ),

            if (isCompleted)
              _buildDetailRow(
                Icons.exit_to_app,
                "Exit",
                booking['exit_time'] != null
                    ? DateFormat('hh:mm a')
                        .format(DateTime.parse(booking['exit_time']))
                    : '-',
              ),

            const SizedBox(height: 8),

            // VEHICLE INFO BOX
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        booking['vehicle_type'] == 'car'
                            ? Icons.directions_car
                            : Icons.motorcycle,
                        color: AppColors.subtleText,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        (booking['number_plate'] ?? 'N/A').toUpperCase(),
                        style: GoogleFonts.poppins(
                            color: AppColors.titleText,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Text(
                    "Slot ${booking['slot_number'] ?? 'N/A'}",
                    style: GoogleFonts.poppins(
                        color: AppColors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            if (!isCancelled && !isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: AppColors.errorRed,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.shade100),
                      ),
                    ),
                    onPressed: () => _cancelBooking(booking),
                    child: Text(
                      "Cancel Booking",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.subtleText),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.subtleText)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.titleText),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
