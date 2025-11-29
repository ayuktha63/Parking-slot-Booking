import 'dart:convert';
import 'dart:ui'; // Required for BackdropFilter
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Import your other screens if needed for navigation
import 'home_screen.dart';
import 'profile_screen.dart';

// --- THEME COLORS (Matched to HomeScreen) ---
class AppColors {
  static const Color background = Color(0xFFF7F7F9);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color subtleText = Color(0xFF9AA0A6);
  static const Color titleText = Color(0xFF222222);
  static const Color accent = Color(0xFF7B61FF);
  static const Color glassBg = Color.fromRGBO(255, 255, 255, 0.15);
  static const Color shadow = Color.fromRGBO(33, 33, 33, 0.08);
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color cancelledGrey = Color(0xFF9E9E9E);
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
          content: Text(
            message,
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _fetchMyBookings() async {
    setState(() {
      _isLoading = true;
    });
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
        String errorMessage = 'Failed to load bookings';
        try {
          final body = jsonDecode(response.body);
          if (body != null && body['message'] != null) {
            errorMessage = body['message'];
          }
        } catch (e) {
          // Ignore
        }
        _showErrorSnackBar(errorMessage);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching bookings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelBooking(dynamic booking) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Cancel Booking?",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: AppColors.titleText)),
        content: Text(
          "Do you really want to cancel this booking?",
          style: GoogleFonts.poppins(color: AppColors.subtleText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("No",
                style: GoogleFonts.poppins(color: AppColors.subtleText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Yes",
                style: GoogleFonts.poppins(
                    color: AppColors.errorRed, fontWeight: FontWeight.bold)),
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
        final data = jsonDecode(response.body);
        _showErrorSnackBar(
            "Cancelled • Refund: ${data["refund_percent"]}% (₹${data["refund_amount"]})");
        _fetchMyBookings();
      } else {
        _showErrorSnackBar("Failed to cancel booking");
      }
    } catch (e) {
      _showErrorSnackBar("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
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
          // --- Main Content ---
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent))
              : _bookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_note,
                              size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 10),
                          Text(
                            "No bookings found.",
                            style: GoogleFonts.poppins(
                                fontSize: 18, color: AppColors.subtleText),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      // Add padding at bottom so the last item isn't hidden by the Glassy Nav
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _bookings.length,
                      itemBuilder: (context, index) {
                        return _buildBookingCard(_bookings[index]);
                      },
                    ),

          // --- Glassy Nav Bar ---
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: _buildGlassyNavBar(),
          ),
        ],
      ),
    );
  }

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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Location Name + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    booking['location'] ?? 'Unknown Location',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.titleText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 20, color: Color(0xFFEEEEEE)),

            // Details
            _buildDetailRow(Icons.calendar_today, "Date",
                DateFormat('MMM dd, yyyy').format(entryTime)),
            _buildDetailRow(Icons.access_time, "Entry",
                DateFormat('hh:mm a').format(entryTime)),

            if (isCancelled) ...[
              _buildDetailRow(
                  Icons.cancel_outlined,
                  "Cancelled",
                  booking['cancelled_at'] != null
                      ? DateFormat('hh:mm a')
                          .format(DateTime.parse(booking['cancelled_at']))
                      : '-'),
              _buildDetailRow(Icons.currency_rupee, "Refund",
                  "${booking['refund_percent'] ?? 0}%"),
            ] else if (isCompleted) ...[
              _buildDetailRow(
                  Icons.exit_to_app,
                  "Exit",
                  booking['exit_time'] != null
                      ? DateFormat('hh:mm a')
                          .format(DateTime.parse(booking['exit_time']))
                      : '-'),
              _buildDetailRow(
                  Icons.currency_rupee,
                  "Paid",
                  booking['amount'] != null
                      ? "₹${booking['amount'].toStringAsFixed(2)}"
                      : '-'),
            ],

            const SizedBox(height: 8),
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
                            fontWeight: FontWeight.w600,
                            color: AppColors.titleText),
                      ),
                    ],
                  ),
                  Text(
                    "Slot ${booking['slot_number'] ?? 'N/A'}",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, color: AppColors.accent),
                  ),
                ],
              ),
            ),

            // Cancel Button
            if (!isCompleted && !isCancelled)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.subtleText),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.subtleText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.titleText,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------ GLASSY NAV BAR ------------------
  Widget _buildGlassyNavBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Home Button
              _navItem(Icons.home_outlined, "Home", () {
                // Navigate back to HomeScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomeScreen(phoneNumber: widget.phoneNumber),
                  ),
                );
              }, isActive: false),

              // Map Button (Assuming Map is same as Bookings for now based on your code)
              _navItem(Icons.map_outlined, "Map", () {
                // Logic for map navigation
              }, isActive: false),

              // CENTER BUTTON (Floating style)
              GestureDetector(
                onTap: () {
                  // Since we are already on bookings, maybe refresh?
                  _fetchMyBookings();
                },
                child: Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons
                        .refresh, // Changed icon to refresh since we are on bookings list
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),

              // Bookings Button (Active State)
              _navItem(Icons.list_alt, "Bookings", () {}, isActive: true),

              // Profile Button
              _navItem(Icons.person_outline, "Profile", () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProfileScreen(phoneNumber: widget.phoneNumber),
                  ),
                );
              }, isActive: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, VoidCallback onTap,
      {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isActive
                  ? AppColors.accent
                  : Colors.grey.shade600, // Adjusted for Light theme
              size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? AppColors.accent
                  : Colors.grey.shade600, // Adjusted for Light theme
            ),
          ),
        ],
      ),
    );
  }
}
