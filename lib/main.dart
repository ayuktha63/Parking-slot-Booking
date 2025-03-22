import 'package:flutter/material.dart';
import 'home_screen.dart'; // Ensure this import points to your HomeScreen file
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart'; // Import Lottie package

void main() {
  runApp(ParkingApp());
}

class ParkingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Parking Booking',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF3F51B5),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFF03A9F4),
          background: Colors.white,
        ),
        fontFamily: GoogleFonts.poppins().fontFamily,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3F51B5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: Colors.black26,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF3F51B5),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      home: const LoadingScreen(), // Set LoadingScreen as the initial screen
    );
  }
}

// Loading Screen with Lottie animation
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();

    // Navigate to HomeScreen after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[100], // Parking lot vibe
      body: Center(
        // Centers everything inside
        child: Column(
          mainAxisSize: MainAxisSize.min, // Prevents full screen stretch
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie animation
            Lottie.asset(
              'assets/lottie/main_car.json',
              width: 300,
              height: 300,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 20),

            // Loading text
            Text(
              "Parking Your Vehicle...",
              style: TextStyle(
                fontSize: 24,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontFamily: GoogleFonts.poppins().fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
