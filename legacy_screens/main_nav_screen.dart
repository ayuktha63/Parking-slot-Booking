import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color accent = Color(0xFF7B61FF); // Purple
  static const Color glassBg = Color.fromRGBO(255, 255, 255, 0.15);
}

/// A clean, responsive glassy bottom nav bar with:
/// - 4 tabs
/// - 1 center floating action button
/// - auto highlight
/// - customizable center icon + tap action
class MainNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onItemSelected;

  /// Custom center button
  final IconData centerIcon;
  final VoidCallback? centerAction;

  const MainNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    this.centerIcon = Icons.local_parking_rounded,
    this.centerAction,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 75,
          padding: const EdgeInsets.symmetric(horizontal: 6), // tighter padding
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _tabItem(Icons.home, "Home", 0),
              _tabItem(Icons.map_outlined, "Map", 1),

              _centerButton(), // Middle Button

              _tabItem(Icons.list_alt, "Bookings", 2),
              _tabItem(Icons.account_circle, "Profile", 3),
            ],
          ),
        ),
      ),
    );
  }

  /// Each side tab (Home, Map, Bookings, Profile)
  Widget _tabItem(IconData icon, String label, int index) {
    final bool active = (currentIndex == index);

    return Expanded(
      child: GestureDetector(
        onTap: () => onItemSelected(index),
        behavior: HitTestBehavior.translucent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 22, color: active ? AppColors.accent : Colors.white70),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.accent : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Middle floating button (customizable)
  Widget _centerButton() {
    final bool active = (currentIndex == 10); // special active index

    return SizedBox(
      width: 70, // Fixed center cell width
      child: GestureDetector(
        onTap: centerAction ?? () => onItemSelected(10),
        child: Container(
          height: 58,
          width: 58,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Icon(
            centerIcon,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
