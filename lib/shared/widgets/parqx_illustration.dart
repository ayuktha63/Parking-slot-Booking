// ─────────────────────────────────────────────────────────────────────────────
// PARQX ILLUSTRATION — the empty-state visual
//
// A composed, painted illustration rather than a bundled asset.
//
// ─────────────────────────────────────────────────────────────────────────────
// WHY PAINTED
//
//   * It takes its colours from the theme, so it cannot drift out of step with
//     the palette the way an exported PNG does the moment a token changes.
//   * It is a few hundred bytes of code instead of a multi-resolution asset set
//     (1x/2x/3x), and it is resolution-independent by construction.
//   * It is honest about what it is. A stock illustration of a car park bought
//     from a marketplace would be a picture of somebody else's product; this is
//     a diagram made of the app's own shapes.
//
// The construction is deliberately simple: a soft radial glow, a ring, a city
// skyline reduced to rectangles, and one icon that says what the screen is
// about. Restraint is the point — an empty state should read as a considered
// pause, not as a consolation prize.
//
// REDUCED MOTION: the glow does not animate. Nothing here moves at all, because
// an empty state is somewhere a user lands when something they wanted is
// absent, and animation in that moment reads as decoration over a
// disappointment.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

class ParqxIllustration extends StatelessWidget {
  const ParqxIllustration({
    super.key,
    required this.icon,
    this.size = 180,
    this.accent = AppColors.brandMuted,
    this.onDark = true,
  });

  final IconData icon;
  final double size;
  final Color accent;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The glow. A radial gradient rather than a blurred shadow: a shadow
          // would need a shape to cast from, and there isn't one.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: onDark ? 0.22 : 0.14),
                  accent.withValues(alpha: 0),
                ],
                stops: const [0.1, 1],
              ),
            ),
          ),

          // The skyline, behind everything — context, not subject.
          Positioned(
            bottom: size * 0.14,
            child: CustomPaint(
              size: Size(size * 0.92, size * 0.24),
              painter: _SkylinePainter(
                colour: accent.withValues(alpha: onDark ? 0.20 : 0.16),
              ),
            ),
          ),

          Container(
            width: size * 0.46,
            height: size * 0.46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onDark ? AppColors.surfaceRaisedDark : AppColors.surfaceAlt,
              border: Border.all(
                color: accent.withValues(alpha: 0.30),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: size * 0.21, color: accent),
          ),
        ],
      ),
    );
  }
}

/// A city reduced to rectangles.
///
/// Fixed proportions, not random: a randomised skyline would redraw differently
/// on every rebuild, which is the kind of thing nobody notices until it is
/// captured in two screenshots side by side.
class _SkylinePainter extends CustomPainter {
  const _SkylinePainter({required this.colour});

  final Color colour;

  /// (x, width, height) as fractions of the canvas.
  static const List<(double, double, double)> _buildings = [
    (0.00, 0.11, 0.42),
    (0.12, 0.08, 0.68),
    (0.21, 0.13, 0.52),
    (0.35, 0.09, 0.88),
    (0.45, 0.12, 0.62),
    (0.58, 0.10, 1.00),
    (0.69, 0.08, 0.46),
    (0.78, 0.12, 0.74),
    (0.91, 0.09, 0.38),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = colour;

    for (final (x, w, h) in _buildings) {
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          x * size.width,
          size.height * (1 - h),
          w * size.width,
          size.height * h,
        ),
        topLeft: const Radius.circular(2),
        topRight: const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_SkylinePainter old) => old.colour != colour;
}
