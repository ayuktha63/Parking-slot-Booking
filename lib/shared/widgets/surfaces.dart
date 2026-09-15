// ─────────────────────────────────────────────────────────────────────────────
// SURFACES
//
// Most content in this app sits directly on the white page. A surface is used
// only when something must read as a single object: a grey "fill" group, or a
// lifted card for the one thing on a screen that is live.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

enum SurfaceLevel {
  /// Grey fill, no shadow.
  flat,

  /// White with a hairline border.
  outlined,

  /// White, lifted off the page.
  raised,
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.level = SurfaceLevel.flat,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.width,
    this.clip = false,
  });

  final Widget child;
  final SurfaceLevel level;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final double? width;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.card;
    final (Color background, List<BoxShadow> shadows, Border? border) = switch (level) {
      SurfaceLevel.flat => (color ?? AppColors.fillSubtle, AppShadows.none, null),
      SurfaceLevel.outlined => (
          color ?? AppColors.surface,
          AppShadows.none,
          Border.all(color: AppColors.line, width: 1),
        ),
      SurfaceLevel.raised => (color ?? AppColors.surface, AppShadows.card, null),
    };
    return Container(
      width: width,
      margin: margin,
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        boxShadow: shadows,
        border: border,
      ),
      child: child,
    );
  }
}

/// A 1px divider, optionally indented to line up with row text.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0, this.endIndent = 0});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: const SizedBox(
        height: 1,
        width: double.infinity,
        child: ColoredBox(color: AppColors.line),
      ),
    );
  }
}

/// The handle at the top of a draggable sheet.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 5,
        margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
        decoration: const BoxDecoration(
          color: AppColors.lineStrong,
          borderRadius: AppRadius.chip,
        ),
      ),
    );
  }
}

/// A slowly breathing dot for things that are live right now.
class LivePulse extends StatefulWidget {
  const LivePulse({super.key, this.color = AppColors.positiveBright, this.size = 8});

  final Color color;
  final double size;

  @override
  State<LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<LivePulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (context.reduceMotion) return dot;
    return SizedBox(
      width: widget.size * 2.4,
      height: widget.size * 2.4,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_controller.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t) * 0.5,
                child: Container(
                  width: widget.size * (1 + t * 1.4),
                  height: widget.size * (1 + t * 1.4),
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                ),
              ),
              child!,
            ],
          );
        },
        child: dot,
      ),
    );
  }
}

/// A white gradient that lifts floating controls off a busy map or photo.
class FadeEdge extends StatelessWidget {
  const FadeEdge({super.key, this.height = 120, this.fromTop = true, this.strength = 0.9});

  final double height;
  final bool fromTop;
  final double strength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              AppColors.white.withValues(alpha: strength),
              AppColors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
