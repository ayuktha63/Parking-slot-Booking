import 'dart:ui';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'my_bookings_screen.dart';
import 'profile_screen.dart';

// Define the colors used in the main nav bar
class NavColors {
  static const Color accentPurple = Color(0xFF7B61FF);
  static const Color iconColor = Color(0xFF7B61FF);
  static const Color unselectedIcon = Colors.grey;
  static const Color centerButtonBg = Color(0xFF7B61FF);
  static const Color navBg = Colors.white;
}

class MainNavScreen extends StatefulWidget {
  final String phoneNumber;
  const MainNavScreen({super.key, required this.phoneNumber});

  @override
  _MainNavScreenState createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  // Define the screens for each tab
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Initialize screens, passing the phoneNumber to relevant screens
    _pages = [
      HomeScreen(phoneNumber: widget.phoneNumber), // Index 0: Home
      const Center(child: Text("Map Page (Coming Soon)")), // Index 1: Map
      const Center(child: Text("Parking Action")), // Index 2: Center Button
      MyBookingsScreen(phoneNumber: widget.phoneNumber), // Index 3: Bookings
      ProfileScreen(phoneNumber: widget.phoneNumber), // Index 4: Profile
    ];
  }

  void _onNavTap(int index) {
    // Prevent tapping the Center Button (Index 2) from changing the page
    // if it's meant to trigger a modal or action, but allow the animation
    // to complete if you want the purple pill to move under it temporarily.
    // I'll keep the current logic which treats it as a selectable page.
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps all pages alive (so they don't reload when switching)
      body: Stack(
        children: [
          // 1. The main content area
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),

          // 2. THE FLOATING NAV BAR
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: _GlassyNavBar(
              currentIndex: _currentIndex,
              onTap: _onNavTap,
            ),
          ),
        ],
      ),
    );
  }
}

// --- EXTRACTED NAV BAR WIDGET ---
class _GlassyNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _GlassyNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  // Helper method to build a standard navigation item
  Widget _navItem(IconData icon, int index) {
    bool isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque, // Ensures clicks are caught
      child: SizedBox(
        width: 50,
        height: 75,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.2 : 1.0, // Icon grows when selected
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isSelected
                    ? NavColors.iconColor
                    : NavColors.unselectedIcon.withOpacity(0.6),
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build the central, elevated navigation item
  Widget _centerNavItem(int index) {
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          color: NavColors.centerButtonBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: NavColors.centerButtonBg.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: const Icon(Icons.local_parking_rounded,
            color: Colors.white, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This calculates where the purple pill should be.
    // It maps index 0..4 to AlignmentX -1.0, -0.5, 0.0, 0.5, 1.0
    // Index 0: (0 - 2) * 0.5 = -1.0 (far left)
    // Index 2: (2 - 2) * 0.5 = 0.0 (center)
    // Index 4: (4 - 2) * 0.5 = 1.0 (far right)
    double alignmentX = (currentIndex - 2) * 0.5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 75,
          decoration: BoxDecoration(
            color: NavColors.navBg.withOpacity(0.85),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 🟣 1. THE MOVING PURPLE PILL (The smooth animation magic)
              AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.fastOutSlowIn, // Smooth iOS style curve
                alignment: Alignment(alignmentX, 1.0), // Moves horizontally
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 0), // Sticks to bottom
                  decoration: BoxDecoration(
                    color: NavColors.accentPurple,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(5)),
                    boxShadow: [
                      BoxShadow(
                        color: NavColors.accentPurple.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      )
                    ],
                  ),
                ),
              ),

              // 2. THE ICONS ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(Icons.home_rounded, 0),
                  _navItem(Icons.map_rounded, 1),
                  _centerNavItem(2), // Center Button (Floating)
                  _navItem(Icons.confirmation_number_rounded, 3), // Bookings
                  _navItem(Icons.person_rounded, 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
