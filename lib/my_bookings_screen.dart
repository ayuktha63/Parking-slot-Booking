import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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

  Future<void> _fetchMyBookings() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse('http://$apiHost:3000/api/users/bookings/${widget.phoneNumber}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _bookings = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        print('Failed to load bookings: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching bookings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "My Bookings",
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3F51B5),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_busy, size: 80, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text(
                        "No bookings found.",
                        style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Start by booking your first spot!",
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
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
                    final formattedDate = DateFormat('MMM dd, yyyy').format(entryTime);
                    final formattedTime = DateFormat('hh:mm a').format(entryTime);
                    final statusColor = booking['status'] == 'completed' ? Colors.green : Colors.blue;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  booking['location'] ?? 'N/A',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    booking['status'] ?? 'N/A',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: statusColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow(Icons.calendar_today, "Date", formattedDate),
                            _buildDetailRow(Icons.access_time, "Time", formattedTime),
                            _buildDetailRow(
                                booking['vehicle_type'] == 'car'
                                    ? Icons.directions_car
                                    : Icons.motorcycle,
                                "Vehicle",
                                "${booking['number_plate'] ?? 'N/A'} (${booking['vehicle_type'] ?? 'N/A'})"),
                            _buildDetailRow(
                                Icons.confirmation_number,
                                "Slot",
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
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            "$label:",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}