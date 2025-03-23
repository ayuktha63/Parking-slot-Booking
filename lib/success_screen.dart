import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'dart:math' as math;
import 'package:share/share.dart';

class SuccessScreen extends StatelessWidget {
  final String location;
  final DateTime date;
  final TimeOfDay time;
  final String vehicleType;
  final List<int> slots;

  const SuccessScreen({super.key, 
    required this.location,
    required this.date,
    required this.time,
    required this.vehicleType,
    required this.slots,
  });

  void _shareReceipt(BuildContext context) {
    final String shareText = '''
Parking Booking Receipt
----------------------
Location: $location
Date: ${date.day}/${date.month}/${date.year}
Time: ${time.format(context)}
Vehicle Type: $vehicleType
Parking Slots: ${slots.join(", ")}
Total Amount: \$${(5 * slots.length).toStringAsFixed(2)}
Booking ID: #${1000 + math.Random().nextInt(9000)}

Please arrive 15 minutes before your booking time.
''';

    Share.share(
      shareText,
      subject: 'Parking Booking Receipt',
      sharePositionOrigin: Rect.fromLTWH(
        0,
        0,
        MediaQuery.of(context).size.width,
        MediaQuery.of(context).size.height / 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text("Booking Confirmed"),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 20),
                    _buildSuccessAnimation(),
                    SizedBox(height: 20),
                    Text(
                      "Booking Confirmed!",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF303030),
                      ),
                    ),
                    SizedBox(height: 10),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.7,
                      child: Text(
                        "Your parking spot has been successfully reserved.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
                    _buildBookingDetailCard(context),
                    SizedBox(height: 20),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 20),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Color(0xFF4CAF50).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF4CAF50),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Please arrive 15 minutes before your booking time. Your QR code has been sent to your email.",
                              style: TextStyle(
                                color: Color(0xFF4CAF50),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => HomeScreen()),
                          (route) => false,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color(0xFF3F51B5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        "Go to Home",
                        style: TextStyle(
                          color: Color(0xFF3F51B5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _shareReceipt(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3F51B5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Share Receipt",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return Container(
      height: 150,
      width: 150,
      decoration: BoxDecoration(
        color: Color(0xFF4CAF50).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.check_circle,
          size: 100,
          color: Color(0xFF4CAF50),
        ),
      ),
    );
  }

  Widget _buildBookingDetailCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF3F51B5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Booking Details",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "#${1000 + math.Random().nextInt(9000)}",
                    style: TextStyle(
                      color: Color(0xFF3F51B5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailItem(Icons.location_on, "Location", location),
                Divider(height: 24),
                _buildDetailItem(
                  Icons.calendar_today,
                  "Date",
                  "${date.day}/${date.month}/${date.year}",
                ),
                Divider(height: 24),
                _buildDetailItem(
                  Icons.access_time,
                  "Time",
                  time.format(context),
                ),
                Divider(height: 24),
                _buildDetailItem(
                  vehicleType == "Car"
                      ? Icons.directions_car
                      : Icons.motorcycle,
                  "Vehicle Type",
                  vehicleType,
                ),
                Divider(height: 24),
                _buildDetailItem(
                  Icons.confirmation_number,
                  "Parking Slots",
                  slots.join(", "),
                ),
                Divider(height: 24),
                _buildDetailItem(
                  Icons.attach_money,
                  "Total Amount",
                  "\$${(5 * slots.length).toStringAsFixed(2)}",
                  isHighlighted: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value,
      {bool isHighlighted = false}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Color(0xFF3F51B5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Color(0xFF3F51B5),
            size: 22,
          ),
        ),
        SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                color: isHighlighted ? Color(0xFF3F51B5) : Color(0xFF303030),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
