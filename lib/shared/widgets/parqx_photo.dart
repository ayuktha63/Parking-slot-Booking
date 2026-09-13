// ─────────────────────────────────────────────────────────────────────────────
// PARQX PHOTO
//
// Every photograph in the product goes through here: discovery cards, the
// parking detail hero, booking rows, active parking, the operator's photo
// manager.
//
// ─────────────────────────────────────────────────────────────────────────────
// WHY ONE COMPONENT
//
// A network image has four states — not one — and each of them is a design
// decision that must be made the same way everywhere:
//
//   no url     the lot has no photograph. NOT an error, and the commonest case
//              for a newly-onboarded operator.
//   loading    bytes in flight.
//   failed     a dead URL, a flat network, an expired object.
//   loaded     the photograph.
//
// Scattering those across six screens is how an app ends up showing a grey box
// on one screen, a broken-image glyph on another, and a spinner that never
// stops on a third.
//
// ─────────────────────────────────────────────────────────────────────────────
// THE HONESTY RULE
//
// When there is no photograph, this draws a MONOGRAM: a gradient seeded from
// the lot's name, with its initials. It is decoration and it claims nothing.
//
// It is deliberately NOT a stock photograph of some other car park. A generic
// image of a parking garage attached to a named, located, bookable lot is a
// lie about a place a customer is about to drive to — and it is a lie that
// looks exactly like the truth, which is the worst kind. The monogram is
// obviously not a photograph, and that is the point.
//
// The gradient is deterministic, so a lot keeps its colour between sessions and
// between the card and the detail screen, which makes a list scannable by
// shape before it is read.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

class ParqxPhoto extends StatelessWidget {
  const ParqxPhoto({
    super.key,
    required this.url,
    required this.seed,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.dimmed = false,
    this.showMonogramInitials = true,
  });

  /// Null or empty when the lot has no photograph.
  final String? url;

  /// What the fallback is generated from — the lot's name, or the plate.
  final String seed;

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  /// Desaturates for a closed lot or a completed booking.
  final bool dimmed;

  /// False for large heroes where two big letters look like a placeholder
  /// rather than a mark.
  final bool showMonogramInitials;

  bool get _hasUrl => url != null && url!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.photo;

    Widget content = _hasUrl
        ? CachedNetworkImage(
            imageUrl: url!,
            fit: fit,
            width: width,
            height: height,
            fadeInDuration: AppMotion.normal,
            // A shimmering monogram, not a grey rectangle: the placeholder is
            // the same shape and colour as what may replace it, so a list does
            // not visibly re-colour as photographs land.
            placeholder: (_, __) => _Monogram(
              seed: seed,
              showInitials: showMonogramInitials,
              shimmer: true,
            ),
            // A dead URL falls back to the monogram, never to a broken-image
            // glyph. The lot is still real and still bookable.
            errorWidget: (_, __, ___) =>
                _Monogram(seed: seed, showInitials: showMonogramInitials),
          )
        : _Monogram(seed: seed, showInitials: showMonogramInitials);

    if (dimmed) {
      content = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0, 0, 0, 0.6, 0, //
        ]),
        child: content,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: width, height: height, child: content),
    );
  }
}

/// The no-photograph fallback.
class _Monogram extends StatelessWidget {
  const _Monogram({
    required this.seed,
    this.showInitials = true,
    this.shimmer = false,
  });

  final String seed;
  final bool showInitials;
  final bool shimmer;

  /// Navy-compatible ramps. Every one of these sits in the same temperature as
  /// the app's ground, so a wall of monograms still looks like one product.
  static const List<List<Color>> _ramps = [
    [Color(0xFF4C3BD1), Color(0xFF241A6B)],
    [Color(0xFF106B5A), Color(0xFF0A3A33)],
    [Color(0xFF1E5BAF), Color(0xFF122F63)],
    [Color(0xFF9A4A2B), Color(0xFF4E2315)],
    [Color(0xFF7A2F75), Color(0xFF3C1540)],
    [Color(0xFF2B6480), Color(0xFF143544)],
  ];

  String get _initials {
    final words =
        seed.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final w = words.first;
      return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hash = seed.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    final ramp = _ramps[hash % _ramps.length];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ramp,
        ),
      ),
      child: Center(
        child: showInitials
            ? Text(
                _initials,
                style: AppTypography.numeric(
                  size: 18,
                  weight: FontWeight.w800,
                  color: AppColors.white.withValues(alpha: shimmer ? 0.35 : 0.9),
                  letterSpacing: 0.5,
                ),
              )
            : Icon(
                Icons.local_parking_rounded,
                color: AppColors.white.withValues(alpha: shimmer ? 0.14 : 0.22),
                size: 44,
              ),
      ),
    );
  }
}

/// A photograph with the product's standard scrim, for text laid over it.
///
/// The scrim is not optional styling: a caption over an arbitrary user-uploaded
/// photograph is unreadable roughly half the time, and which half is not
/// knowable in advance.
class ParqxPhotoHeader extends StatelessWidget {
  const ParqxPhotoHeader({
    super.key,
    required this.url,
    required this.seed,
    required this.child,
    this.height,
    this.borderRadius,
    this.topActions,
    this.badge,
  });

  final String? url;
  final String seed;

  /// Laid over the bottom of the photograph, inside the scrim.
  final Widget child;

  final double? height;
  final BorderRadius? borderRadius;

  /// Back / share / favourite, laid over the top.
  final Widget? topActions;

  /// A floating label — the slot code on Active Parking.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ParqxPhoto(
              url: url,
              seed: seed,
              borderRadius: BorderRadius.zero,
              showMonogramInitials: false,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppGradients.photoScrim),
            ),
            if (topActions != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(bottom: false, child: topActions!),
              ),
            if (badge != null)
              Positioned(right: AppSpacing.lg, bottom: AppSpacing.xxxl + 8, child: badge!),
            Positioned(
              left: AppSpacing.pageInset,
              right: AppSpacing.pageInset,
              bottom: AppSpacing.lg,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
