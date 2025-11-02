import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
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

class MyBookingsScreen extends StatefulWidget {
  final String phoneNumber;

  const MyBookingsScreen({super.key, required this.phoneNumber});

  @override
  _MyBookingsScreenState createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<dynamic> _bookings = [];
  bool _isLoading = true;
  String apiHost = '10.0.2.2';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      apiHost = '127.0.0.1';
    }
    _fetchMyBookings();
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
      final response = await http.get(
        Uri.parse(
            'http://$apiHost:3000/api/users/bookings/${widget.phoneNumber}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _bookings = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        _showErrorSnackBar('Failed to load bookings: ${response.statusCode}');
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
                    final formattedDate =
                        DateFormat('MMM dd, yyyy').format(entryTime);
                    final formattedTime =
                        DateFormat('hh:mm a').format(entryTime);

                    // --- MODIFIED ---
                    // Determine status, background color, and text color
                    final bool isCompleted =
                        (booking['status'] ?? 'active') == 'completed';
                    final String statusText = booking['status'] ?? 'active';

                    final Color statusBgColor = isCompleted
                        ? AppColors.infoItemBg // Dark grey for completed
                        : AppColors.primaryText; // White for active

                    final Color statusTextColor = isCompleted
                        ? AppColors.primaryText // White text for completed
                        : AppColors.darkText; // Black text for active
                    // --- END MODIFIED ---

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
                              crossAxisAlignment:
                                  CrossAxisAlignment.start, // Align top
                              children: [
                                // Wrapped with Flexible to constrain width
                                Flexible(
                                  child: Text(
                                    booking['location'] ?? 'N/A',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryText,
                                    ),
                                    // Added overflow handling
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                                // Added spacing so chip doesn't touch text
                                const SizedBox(width: 8),
                                // --- MODIFIED ---
                                Chip(
                                  label: Text(
                                    statusText, // Use status text variable
                                    style: GoogleFonts.poppins(
                                      color:
                                          statusTextColor, // Use status text color
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor:
                                      statusBgColor, // Use status bg color
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                                // --- END MODIFIED ---
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                                Icons.calendar_today, "Date", formattedDate),
                            _buildDetailRow(
                                Icons.access_time, "Time", formattedTime),
                            _buildDetailRow(
                                booking['vehicle_type'] == 'car'
                                    ? Icons.directions_car
                                    : Icons.motorcycle,
                                "Vehicle",
                                "${booking['number_plate'] ?? 'N/A'} (${booking['vehicle_type'] ?? 'N/A'})"),
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
          Text(
            "$label:",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(width: 4),
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
