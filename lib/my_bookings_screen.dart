import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io'
    show Platform; // Imported for more robust local host determination

// --- THEME COLORS (Dark Mode) ---
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

  static const Color markerColor =
      Color(0xFF0A84FF); // Blue accent (Active status)
  static const Color routeColor = Color(0xFF5AC8FA);
  static const Color outlinedButtonColor = Color(0xFF8E8E93);
  static const Color elevatedButtonBg = Color(0xFFFFFFFF);

  static const Color shadow = Color.fromRGBO(0, 0, 0, 0.3);
  static const Color errorRed = Color(0xFFD32F2F); // A dark red for errors
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
    // Check for local development environment
    if (kIsWeb &&
        (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1')) {
      apiHost = '127.0.0.1:3000'; // Assuming local server runs on port 3000
      apiScheme = 'http';
    }
    // If running on a physical device/emulator pointing to a local server,
    // you would uncomment and set a fixed local IP here, e.g.:
    // else if (!kIsWeb) {
    //   apiHost = 'YOUR_LOCAL_IP:3000';
    //   apiScheme = 'http';
    // }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: AppColors.primaryText),
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
        // Attempt to decode error message if available
        String errorMessage = 'Failed to load bookings: ${response.statusCode}';
        try {
          final body = jsonDecode(response.body);
          if (body != null && body['message'] != null) {
            errorMessage = body['message'];
          }
        } catch (e) {
          // Ignore JSON decoding error, use default message
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        title: Text(
          "My Bookings",
          style: GoogleFonts.poppins(color: AppColors.primaryText),
        ),
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.primaryText, // For back button
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
              color: AppColors.primaryText,
            ))
          : _bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_busy,
                          size: 80, color: AppColors.secondaryText),
                      const SizedBox(height: 10),
                      Text(
                        "No bookings found.",
                        style: GoogleFonts.poppins(
                            fontSize: 18, color: AppColors.secondaryText),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Start by booking your first spot!",
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: AppColors.hintText),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _bookings.length,
                  itemBuilder: (context, index) {
                    final booking = _bookings[index];
                    final entryTime = DateTime.parse(booking['entry_time']);

                    // Status is now inferred on the server, but we use exit_time as the primary check
                    final bool isCompleted = booking['exit_time'] != null ||
                        (booking['status'] ?? 'active') == 'completed';
                    final String statusText =
                        isCompleted ? 'Completed' : 'Active';

                    final Color statusBgColor = isCompleted
                        ? AppColors.infoItemBg // Subtle grey for completed
                        : AppColors.markerColor; // Blue for active

                    final Color statusTextColor = isCompleted
                        ? AppColors
                            .secondaryText // Light grey text for completed
                        : AppColors.primaryText; // White text for active

                    return Card(
                      color: AppColors.cardSurface,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      shadowColor: AppColors.shadow,
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Location Name
                                Flexible(
                                  child: Text(
                                    booking['location'] ?? 'N/A',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryText,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Status Chip
                                Chip(
                                  label: Text(
                                    statusText,
                                    style: GoogleFonts.poppins(
                                      color: statusTextColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  backgroundColor: statusBgColor,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Entry Details
                            _buildDetailRow(Icons.calendar_today, "Entry Date",
                                DateFormat('MMM dd, yyyy').format(entryTime)),
                            _buildDetailRow(Icons.access_time, "Entry Time",
                                DateFormat('hh:mm a').format(entryTime)),

                            // Completed Details (Only show if completed)
                            if (isCompleted) ...[
                              const Divider(
                                  height: 20, color: AppColors.infoItemBg),
                              _buildDetailRow(
                                  Icons.exit_to_app_rounded,
                                  "Exit Time",
                                  booking['exit_time'] != null
                                      ? DateFormat('hh:mm a').format(
                                          DateTime.parse(booking['exit_time']))
                                      : 'N/A'),
                              _buildDetailRow(
                                  Icons.payments,
                                  "Amount Paid",
                                  booking['amount'] != null
                                      ? "₹${booking['amount'].toStringAsFixed(2)}"
                                      : 'N/A'),
                            ],

                            const Divider(
                                height: 20, color: AppColors.infoItemBg),

                            // Vehicle & Slot Details
                            _buildDetailRow(
                                booking['vehicle_type'] == 'car'
                                    ? Icons.directions_car
                                    : Icons.motorcycle,
                                "Vehicle",
                                "${(booking['number_plate'] ?? 'N/A').toUpperCase()} (${booking['vehicle_type'] ?? 'N/A'})"),
                            _buildDetailRow(Icons.confirmation_number, "Slot",
                                "Slot ${booking['slot_number'] ?? 'N/A'}"),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.secondaryText),
          const SizedBox(width: 8),
          SizedBox(
            width: 90, // Fixed width for label for alignment
            child: Text(
              "$label:",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
