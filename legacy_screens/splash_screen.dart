import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user_login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoScaleController;
  late AnimationController _textSlideController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _slide;
  late Animation<double> _fade;

  final TextStyle _textStyle = GoogleFonts.poppins(
    fontSize: 42,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  @override
  void initState() {
    super.initState();

    _logoScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoScaleAnimation = CurvedAnimation(
      parent: _logoScaleController,
      curve: Curves.easeOutExpo,
    );

    _textSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _slide = CurvedAnimation(
      parent: _textSlideController,
      curve: Curves.easeOutCubic,
    );

    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _textSlideController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _startSequence();
  }

  void _startSequence() async {
    await _logoScaleController.forward();
    await _textSlideController.forward();
    await Future.delayed(const Duration(milliseconds: 1600));
    _goNext();
  }

  void _goNext() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 900),
        pageBuilder: (_, __, ___) => const UserLoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _logoScaleController.dispose();
    _textSlideController.dispose();
    super.dispose();
  }

  double _textWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    const double logoSize = 60;
    const double spacing = 8;

    // Q shift offset
    const double logoOffset = 15; // move right

    final double parWidth = _textWidth("PAR", _textStyle);
    final double xWidth = _textWidth("X", _textStyle);

    final double finalTotalWidth = parWidth + logoSize + xWidth + (2 * spacing);

    final double parSlideTarget = finalTotalWidth / 2 - parWidth / 2;

    // FIX: move X left by same amount Q moved right
    final double xSlideTarget = (finalTotalWidth / 2 - xWidth / 2) - logoOffset;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // PAR Text
            AnimatedBuilder(
              animation: _slide,
              builder: (_, child) {
                double slideOffset = -_slide.value * parSlideTarget;
                return Opacity(
                  opacity: _fade.value,
                  child: Transform.translate(
                    offset: Offset(slideOffset, 0),
                    child: child,
                  ),
                );
              },
              child: Text("PAR", style: _textStyle),
            ),

            // X Text
            AnimatedBuilder(
              animation: _slide,
              builder: (_, child) {
                double slideOffset = _slide.value * xSlideTarget;
                return Opacity(
                  opacity: _fade.value,
                  child: Transform.translate(
                    offset: Offset(slideOffset, 0),
                    child: child,
                  ),
                );
              },
              child: Text("X", style: _textStyle),
            ),

            // Q Logo (shifted right)
            Transform.translate(
              offset: const Offset(logoOffset, 0),
              child: ScaleTransition(
                scale: _logoScaleAnimation,
                child: Image.asset(
                  "assets/logo_q.png",
                  height: logoSize,
                  fit: BoxFit.contain,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
