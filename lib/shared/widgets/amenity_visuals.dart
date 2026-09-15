// ─────────────────────────────────────────────────────────────────────────────
// AMENITIES
//
// The server sends codes; this maps them to an icon and a label. Unknown codes
// still render readably rather than disappearing.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

abstract final class AmenityVisuals {
  const AmenityVisuals._();

  static const Map<String, IconData> _icons = <String, IconData>{
    'covered': Icons.roofing_rounded,
    'cctv': Icons.videocam_outlined,
    'security': Icons.shield_outlined,
    'ev_charging': Icons.ev_station_outlined,
    'valet': Icons.room_service_outlined,
    'accessible': Icons.accessible_rounded,
    'open_24_7': Icons.schedule_rounded,
    'car_wash': Icons.local_car_wash_outlined,
    'lift': Icons.elevator_outlined,
    'washroom': Icons.wc_rounded,
  };

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

  static String labelFor(String code) {
    final known = _labels[code];
    if (known != null) return known;
    if (code.isEmpty) return '';
    final spaced = code.replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  static const List<String> _priority = <String>[
    'covered',
    'ev_charging',
    'cctv',
    'security',
    'accessible',
    'lift',
    'valet',
    'washroom',
    'car_wash',
    'open_24_7',
  ];

  static List<String> topCodes(List<String> codes, {int limit = 3}) {
    if (codes.isEmpty) return const [];
    final ranked = [...codes]..sort((a, b) {
        final ia = _priority.indexOf(a);
        final ib = _priority.indexOf(b);
        return (ia == -1 ? _priority.length : ia).compareTo(ib == -1 ? _priority.length : ib);
      });
    return ranked.take(limit).toList(growable: false);
  }
}

/// "Covered · EV charging · CCTV" — compact, for rows.
class AmenityLine extends StatelessWidget {
  const AmenityLine({super.key, required this.codes, this.limit = 3});

  final List<String> codes;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final shown = AmenityVisuals.topCodes(codes, limit: limit);
    if (shown.isEmpty) return const SizedBox.shrink();
    final extra = codes.length - shown.length;
    final text = [
      ...shown.map(AmenityVisuals.labelFor),
      if (extra > 0) '+$extra',
    ].join(' · ');
    return Text(
      text,
      style: context.text.bodySmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// An amenity as a grid cell: icon over label.
class AmenityTile extends StatelessWidget {
  const AmenityTile({super.key, required this.code, this.label});

  final String code;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(AmenityVisuals.iconFor(code), size: AppSizes.iconMd, color: AppColors.ink),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label ?? AmenityVisuals.labelFor(code),
            style: context.text.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
