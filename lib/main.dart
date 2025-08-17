import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user_login_screen.dart'; // Import the new user login screen

void main() {
  runApp(const ParkingApp());
}

class ParkingApp extends StatelessWidget {
  const ParkingApp({super.key});

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
          surface: Colors.white,
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
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.deepPurple,
          selectionColor: Colors.deepPurpleAccent,
          selectionHandleColor: Colors.purple,
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
      home: const UserLoginScreen(), // Set the home to the new UserLoginScreen
    );
  }
}