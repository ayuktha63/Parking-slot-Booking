// ─────────────────────────────────────────────────────────────────────────────
// SURFACES
//
// Containers that separate by DEPTH rather than by outline.
//
// The old UI drew a 1px border around cards, chips, fields, banners, tiles and
// list rows simultaneously. When every element is outlined, outlines stop
// carrying information: the screen becomes a wireframe where nothing is nearer
// or further than anything else, and the eye has no route through it. That flat,
// boxed-in quality is a large part of what "generic Flutter app" describes.
//
// The replacement is an explicit elevation ladder. Each step is a surface colour
// AND a shadow, applied together, so "raised" is a single decision rather than a
// colour choice on one line and a blur radius twenty lines later.
//
// Rungs, in the order the eye should find them:
//
//   flat     — no shadow, tinted fill. Grouping only. Wells, inset rows.
//   raised   — the default card. Sits on the canvas.
//   floating — over the map, or over other cards. Nothing to rest on, so the
//              shadow does all the work.
//   glass    — translucent and blurred; belongs to whatever is behind it.
//              Reserved for chrome over the map.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

enum SurfaceLevel { flat, raised, floating }

/// A depth-aware container. The default building block for everything that is a
/// distinct object on screen.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.level = SurfaceLevel.raised,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.borderColor,
    this.width,
    this.height,
    this.clip = false,
  });

  final Widget child;
  final SurfaceLevel level;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;

  /// An outline, for the rare case where one carries meaning — a selected
  /// state, a destructive confirmation. Null everywhere else, on purpose.
  final Color? borderColor;

  final double? width;
  final double? height;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.card;
    final colors = context.colors;

    final (Color background, List<BoxShadow> shadows) = switch (level) {
      SurfaceLevel.flat => (color ?? colors.surfaceContainer, AppShadows.none),
      SurfaceLevel.raised => (color ?? colors.surface, AppShadows.md),
      SurfaceLevel.floating => (color ?? colors.surface, AppShadows.floating),
    };

    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        boxShadow: shadows,
        border: borderColor == null ? null : Border.all(color: borderColor!, width: 1.5),
      ),
      child: child,
    );
  }
}

/// Translucent, blurred chrome for content floating over the map.
///
/// The map is the product's signature surface, and chrome that sits on it as an
/// opaque white slab punches a hole through it. Glass keeps the map continuous
/// and readable underneath while still carrying legible text.
///
/// PERFORMANCE: `BackdropFilter` samples and blurs everything painted behind it
/// every frame, and the map behind it repaints on every pan. That is affordable
/// for small chrome and ruinous for a full-screen panel, so this is deliberately
/// used only for compact controls — the search pill, the status strip — never as
/// a sheet background. Sheets are opaque [AppSurface]s.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.blur = 18,
    this.opacity = 0.82,
    this.onDark = false,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final double opacity;

  /// Tints toward the dark map ink instead of the light surface — for chrome
  /// that should read as part of the map rather than as part of the app.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.chip;
    final base = onDark ? AppColors.mapOverlayInk : context.colors.surface;

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: base.withValues(alpha: opacity),
            borderRadius: radius,
            // A hairline highlight along the top edge. This is what separates
            // "translucent panel" from "semi-transparent rectangle": real glass
            // catches light on its edge.
            border: Border.all(
              color: onDark
                  ? AppColors.white.withValues(alpha: 0.10)
                  : AppColors.white.withValues(alpha: 0.65),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A short gradient that fades content out beneath floating chrome.
///
/// Used at the top of the map so status-bar-adjacent controls stay readable over
/// arbitrary map content, and at the top of a scrolling sheet so rows dissolve
/// under the grabber instead of sliding beneath a hard line.
class FadeEdge extends StatelessWidget {
  const FadeEdge({
    super.key,
    required this.gradient,
    this.height = 96,
  });

  const FadeEdge.mapTop({super.key, this.height = 132})
      : gradient = AppGradients.mapTopFade;

  const FadeEdge.mapBottom({super.key, this.height = 180})
      : gradient = AppGradients.mapBottomFade;

  final LinearGradient gradient;
  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(gradient: gradient),
      ),
    );
  }
}

/// The grabber at the top of a draggable sheet.
///
/// Its own widget because it appears on four sheets and one persistent panel,
/// and because the affordance has to be identical everywhere for people to learn
/// that sheets in this app can be dragged.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: onDark
              ? AppColors.white.withValues(alpha: 0.28)
              : AppColors.borderStrong,
          borderRadius: AppRadius.chip,
        ),
      ),
    );
  }
}

/// A live status dot with a slow halo.
///
/// Marks data that is genuinely streaming from the socket — availability counts,
/// an active session's clock. It is a factual claim, so it goes only where a
/// realtime subscription is actually attached; using it as decoration would make
/// every other number on screen look stale by implication.
class LivePulse extends StatefulWidget {
  const LivePulse({super.key, this.color = AppColors.successBright, this.size = 8});

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

    // A permanently repeating animation is exactly the kind a reduce-motion user
    // is asking to be rid of. The dot stays — it carries meaning — the halo goes.
    if (context.reduceMotion) return dot;

    return SizedBox(
      width: widget.size * 2.6,
      height: widget.size * 2.6,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_controller.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t) * 0.45,
                child: Container(
                  width: widget.size * (1 + t * 1.6),
                  height: widget.size * (1 + t * 1.6),
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
