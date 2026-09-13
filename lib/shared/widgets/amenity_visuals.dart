// ─────────────────────────────────────────────────────────────────────────────
// AMENITY VISUALS
//
// One place that decides what an amenity code looks like, because two surfaces now
// render amenities and they must agree: the detail screen (full chips with labels)
// and the parking card (compact icon row).
//
// This icon map previously lived private inside `parking_detail_screen.dart`. The
// card needed the same thing, and a second copy would have drifted the moment either
// screen gained a code.
//
// WHY A LOCAL LABEL FALLBACK EXISTS
//   The DETAIL endpoint returns full amenity objects — `{code, label, icon}` — and
//   the server's label is always preferred when present. The LIST endpoint returns
//   bare codes (`["cctv", "covered"]`) with no labels, because a summary payload
//   repeated across every result should not carry display strings.
//
//   So a card that wants to say "CCTV" rather than "cctv" has to map it locally.
//   That is presentation, not business logic — nothing here decides whether a lot
//   HAS an amenity, only how an amenity the server already reported is drawn.
//
//   An unknown code is humanised rather than hidden: a lot that genuinely has an
//   amenity this build has never heard of still shows it, spelled out, instead of
//   silently losing a real fact about the place.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../models/parking.dart';

abstract final class AmenityVisuals {
  const AmenityVisuals._();

  /// Mirrors the `amenities` code table. Codes not listed fall back to a neutral
  /// tick, never to a wrong icon.
  static const Map<String, IconData> _icons = <String, IconData>{
    'covered': Icons.roofing_rounded,
    'cctv': Icons.videocam_rounded,
    'security': Icons.shield_rounded,
    'ev_charging': Icons.ev_station_rounded,
    'valet': Icons.front_hand_rounded,
    'accessible': Icons.accessible_rounded,
    'open_24_7': Icons.access_time_rounded,
    'car_wash': Icons.local_car_wash_rounded,
    'lift': Icons.elevator_rounded,
    'washroom': Icons.wc_rounded,
  };

  /// Display labels for the LIST endpoint, which sends codes without labels.
  /// The DETAIL endpoint's own label always wins over these.
  static const Map<String, String> _labels = <String, String>{
    'covered': 'Covered',
    'cctv': 'CCTV',
    'security': 'Security staff',
    'ev_charging': 'EV charging',
    'valet': 'Valet',
    'accessible': 'Accessible',
    'open_24_7': 'Open 24/7',
    'car_wash': 'Car wash',
    'lift': 'Lift access',
    'washroom': 'Washroom',
  };

  static IconData iconFor(String code) => _icons[code] ?? Icons.check_rounded;

  /// Falls back to humanising the code itself — `ev_charging` → `Ev charging` —
  /// so an unrecognised amenity is still reported rather than dropped.
  static String labelFor(String code) {
    final known = _labels[code];
    if (known != null) return known;
    if (code.isEmpty) return '';
    final spaced = code.replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  /// The amenities most worth showing in a space too small for all of them.
  ///
  /// Ordered by what actually changes a parking decision: shelter and safety
  /// first, conveniences last. A driver choosing in the rain cares that it is
  /// covered long before they care that there is a car wash.
  static const List<String> _priority = <String>[
    'covered',
    'cctv',
    'security',
    'ev_charging',
    'accessible',
    'lift',
    'valet',
    'washroom',
    'car_wash',
    'open_24_7',
  ];

  /// Picks up to [limit] codes to show on a card, most decision-relevant first.
  static List<String> topCodes(List<String> codes, {int limit = 3}) {
    if (codes.isEmpty) return const [];
    final ranked = [...codes]..sort((a, b) {
        final ia = _priority.indexOf(a);
        final ib = _priority.indexOf(b);
        // Unknown codes sort last but are still eligible to be shown.
        return (ia == -1 ? _priority.length : ia)
            .compareTo(ib == -1 ? _priority.length : ib);
      });
    return ranked.take(limit).toList(growable: false);
  }
}

/// Full chip with a label. Used where there is room to be explicit.
class AmenityChip extends StatelessWidget {
  const AmenityChip({super.key, required this.code, this.label});

  final String code;

  /// The server's own label, when the endpoint provided one.
  final String? label;

  /// Builds from a detail-endpoint [Amenity], preferring the server's label.
  factory AmenityChip.fromAmenity(Amenity amenity, {Key? key}) => AmenityChip(
        key: key,
        code: amenity.code,
        label: amenity.label.isEmpty ? null : amenity.label,
      );

  @override
  Widget build(BuildContext context) {
    final text = label ?? AmenityVisuals.labelFor(code);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AmenityVisuals.iconFor(code),
            size: AppSizes.iconSm,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(text, style: context.text.labelMedium),
        ],
      ),
    );
  }
}

/// Compact icon row for a card, where labels would not fit.
///
/// Icon-only would fail colour/shape independence and screen readers, so the whole
/// row carries one composed semantic label naming every amenity in words.
class AmenityIconRow extends StatelessWidget {
  const AmenityIconRow({
    super.key,
    required this.codes,
    this.limit = 3,
    this.withLabels = false,
    this.onDark = false,
  });

  final List<String> codes;
  final int limit;

  /// Names beside the glyphs.
  ///
  /// A row of bare icons is a guessing game: a shield could be security or
  /// insurance, a plug could be EV charging or a socket to use. On the discovery
  /// card there is room for the word, and the word is what actually settles a
  /// choice between two otherwise-equal lots.
  final bool withLabels;

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final shown = AmenityVisuals.topCodes(codes, limit: limit);
    if (shown.isEmpty) return const SizedBox.shrink();

    final remaining = codes.length - shown.length;
    final spoken = codes.map(AmenityVisuals.labelFor).join(', ');
    final colour = onDark ? AppColors.inkMutedDark : AppColors.inkSubtle;

    return Semantics(
      label: 'Amenities: $spoken',
      excludeSemantics: true,
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final code in shown)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AmenityVisuals.iconFor(code),
                  // Amenities are tertiary: they break a tie between two lots
                  // that are otherwise equal. At full icon size and full ink
                  // they carried the same weight as the availability count, so
                  // three of them competed with the one number that decides
                  // whether the lot is usable at all.
                  size: AppSizes.iconXs + 1,
                  color: colour,
                ),
                if (withLabels) ...[
                  const SizedBox(width: AppSpacing.xs + 1),
                  // Flexible for the same reason as the card's status line: a
                  // Row inside a Wrap is loosely constrained, so a long label
                  // ("EV charging") overruns rather than wrapping.
                  Flexible(
                    child: Text(
                      AmenityVisuals.labelFor(code),
                      style: context.text.labelSmall?.copyWith(
                        color: colour,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          if (remaining > 0)
            Text(
              '+$remaining',
              style: context.text.labelSmall?.copyWith(
                color: colour,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
    );
  }
}
