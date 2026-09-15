import 'package:flutter/material.dart';
import 'home_screen.dart'; // Make sure AppColors is defined here
import 'dart:math' as math;
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart'; // Import for GoogleFonts

// Re-defining AppColors here for self-containment, or ensure it's imported correctly
// If AppColors is already in home_screen.dart, you might remove this duplicate.
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
  static const Color successGreen = Color(0xFF34C759); // iOS-like success green
  static const Color successGreenLight = Color(0xFF34C759); // For opacity
}

class SuccessScreen extends StatelessWidget {
  final String location;
  final String vehicleType;
  final List<int> slots;
  final DateTime entryDateTime;
  final String phoneNumber; // Added phoneNumber to constructor

  const SuccessScreen({
    super.key,
    required this.location,
    required this.vehicleType,
    required this.slots,
    required this.entryDateTime,
    required this.phoneNumber,
  });

  void _shareReceipt(BuildContext context) {
    final int bookingId = 1000 + math.Random().nextInt(9000);
    // Assuming a flat rate for simplicity
    final double totalAmount = 5 * slots.length.toDouble();

    final String shareText = '''
Parking Booking Receipt
----------------------
Location: $location
Entry: ${entryDateTime.day}/${entryDateTime.month}/${entryDateTime.year} at ${entryDateTime.hour}:${entryDateTime.minute.toString().padLeft(2, '0')}
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
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        title: Text(
          "Booking Confirmed",
          style: GoogleFonts.poppins(color: AppColors.primaryText),
        ),
        backgroundColor: AppColors.appBarColor,
        elevation: 0,
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
                    Text(
                      "Booking Confirmed!",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.7,
                      child: Text(
                        "Your parking spot has been successfully reserved.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: AppColors.secondaryText,
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
                        color: AppColors.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.successGreen.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.successGreen,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Please arrive 15 minutes before your booking time. Your QR code has been sent to your email.",
                              style: GoogleFonts.poppins(
                                color: AppColors.successGreen,
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
                color: AppColors.cardSurface,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
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
                          MaterialPageRoute(
                              builder: (context) =>
                                  HomeScreen(phoneNumber: phoneNumber)),
                          (route) => false,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.outlinedButtonColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        "Go to Home",
                        style: GoogleFonts.poppins(
                          color: AppColors.primaryText,
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
                        backgroundColor: AppColors.elevatedButtonBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.share,
                              size: 18, color: AppColors.darkText),
                          const SizedBox(width: 8),
                          Text(
                            "Share Receipt",
                            style: GoogleFonts.poppins(
                              color: AppColors.darkText,
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
        color: AppColors.successGreen.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.check_circle,
          size: 100,
          color: AppColors.successGreen,
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
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
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
              color: AppColors.cardSurface, // Use card surface for consistency
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
                  style: GoogleFonts.poppins(
                    color: AppColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors
                        .infoItemBg, // Use a slightly different background for the ID badge
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "#$bookingId",
                    style: GoogleFonts.poppins(
                      color: AppColors.primaryText, // Text remains primary
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
                Divider(height: 24, color: AppColors.infoItemBg),
                _buildDetailItem(
                  Icons.login,
                  "Entry",
                  "${entryDateTime.day}/${entryDateTime.month}/${entryDateTime.year} ${entryDateTime.hour}:${entryDateTime.minute.toString().padLeft(2, '0')}",
                ),
                Divider(height: 24, color: AppColors.infoItemBg),
                _buildDetailItem(
                  vehicleType == "Car"
                      ? Icons.directions_car
                      : Icons.motorcycle,
                  "Vehicle Type",
                  vehicleType,
                ),
                Divider(height: 24, color: AppColors.infoItemBg),
                _buildDetailItem(
                  Icons.confirmation_number,
                  "Parking Slots",
                  slots.join(", "),
                ),
                Divider(height: 24, color: AppColors.infoItemBg),
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
            color: AppColors.infoItemBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.secondaryText, // Icon color
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                color: isHighlighted
                    ? AppColors
                        .markerColor // Use a bright accent for highlighted text
                    : AppColors.primaryText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
