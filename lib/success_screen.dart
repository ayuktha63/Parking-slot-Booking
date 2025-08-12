import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'dart:math' as math;
import 'package:share_plus/share_plus.dart';

class SuccessScreen extends StatelessWidget {
  final String location;
  final String vehicleType;
  final List<int> slots;
  final DateTime entryDateTime;
  final DateTime exitDateTime;

  const SuccessScreen({
    super.key,
    required this.location,
    required this.vehicleType,
    required this.slots,
    required this.entryDateTime,
    required this.exitDateTime,
  });

  void _shareReceipt(BuildContext context) {
    final int bookingId = 1000 + math.Random().nextInt(9000);
    final double totalAmount = 5 * slots.length.toDouble();

    final String shareText = '''
Parking Booking Receipt
----------------------
Location: $location
Entry: ${entryDateTime.day}/${entryDateTime.month}/${entryDateTime.year} at ${entryDateTime.hour}:${entryDateTime.minute.toString().padLeft(2, '0')}
Exit: ${exitDateTime.day}/${exitDateTime.month}/${exitDateTime.year} at ${exitDateTime.hour}:${exitDateTime.minute.toString().padLeft(2, '0')}
Vehicle Type: $vehicleType
Parking Slots: ${slots.join(", ")}
Total Amount: \$${totalAmount.toStringAsFixed(2)}
Booking ID: #$bookingId

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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Booking Confirmed"),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildSuccessAnimation(),
                    const SizedBox(height: 20),
                    const Text(
                      "Booking Confirmed!",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF303030),
                      ),
                    ),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 40),
                    _buildBookingDetailCard(context),
                    const SizedBox(height: 20),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFF4CAF50),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Please arrive 15 minutes before your booking time. Your QR code has been sent to your email.",
                              style: TextStyle(
                                color: const Color(0xFF4CAF50),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
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
                          MaterialPageRoute(builder: (context) => const HomeScreen(phoneNumber: '',)),
                              (route) => false,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF3F51B5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "Go to Home",
                        style: TextStyle(
                          color: Color(0xFF3F51B5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _shareReceipt(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3F51B5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
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
        color: const Color(0xFF4CAF50).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.check_circle,
          size: 100,
          color: Color(0xFF4CAF50),
        ),
      ),
    );
  }

  Widget _buildBookingDetailCard(BuildContext context) {
    final int bookingId = 1000 + math.Random().nextInt(9000);
    final double totalAmount = 5 * slots.length.toDouble();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF3F51B5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Booking Details",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "#$bookingId",
                    style: const TextStyle(
                      color: Color(0xFF3F51B5),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailItem(Icons.location_on, "Location", location),
                const Divider(height: 24),
                _buildDetailItem(
                  Icons.login,
                  "Entry",
                  "${entryDateTime.day}/${entryDateTime.month}/${entryDateTime.year} ${entryDateTime.hour}:${entryDateTime.minute.toString().padLeft(2, '0')}",
                ),
                const Divider(height: 24),
                _buildDetailItem(
                  Icons.logout,
                  "Exit",
                  "${exitDateTime.day}/${exitDateTime.month}/${exitDateTime.year} ${exitDateTime.hour}:${exitDateTime.minute.toString().padLeft(2, '0')}",
                ),
                const Divider(height: 24),
                _buildDetailItem(
                  vehicleType == "Car" ? Icons.directions_car : Icons.motorcycle,
                  "Vehicle Type",
                  vehicleType,
                ),
                const Divider(height: 24),
                _buildDetailItem(
                  Icons.confirmation_number,
                  "Parking Slots",
                  slots.join(", "),
                ),
                const Divider(height: 24),
                _buildDetailItem(
                  Icons.attach_money,
                  "Total Amount",
                  "\$${totalAmount.toStringAsFixed(2)}",
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF3F51B5).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF3F51B5),
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
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
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                color: isHighlighted
                    ? const Color(0xFF3F51B5)
                    : const Color(0xFF303030),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
