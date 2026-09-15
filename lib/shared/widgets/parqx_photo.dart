// ─────────────────────────────────────────────────────────────────────────────
// PARKING PHOTOGRAPHY
//
// Shows the operator's real photo when there is one. When there is not, it shows
// a neutral placeholder — a grey tile with a parking glyph — and never a stock
// image pretending to be the lot.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

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
  });

  final String? url;

  /// Kept for call-site stability and future per-lot placeholder variation.
  final String seed;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  /// Greyscale and faded — a closed or finished place.
  final bool dimmed;

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
            fadeInDuration: AppMotion.quick,
            placeholder: (_, __) => const _Placeholder(loading: true),
            errorWidget: (_, __, ___) => const _Placeholder(),
          )
        : const _Placeholder();

    if (dimmed) {
      content = Opacity(
        opacity: 0.55,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0, //
            0.2126, 0.7152, 0.0722, 0, 0, //
            0.2126, 0.7152, 0.0722, 0, 0, //
            0, 0, 0, 1, 0, //
          ]),
          child: content,
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: width, height: height, child: content),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = constraints.biggest.shortestSide;
        final glyph = (shortest.isFinite ? shortest : 64) * 0.36;
        return DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.fill),
          child: Center(
            child: loading
                ? const SizedBox.shrink()
                : Icon(Icons.local_parking_rounded,
                    size: glyph.clamp(16, 64).toDouble(), color: AppColors.inkDisabled),
          ),
        );
      },
    );
  }
}
