// ─────────────────────────────────────────────────────────────────────────────
// FILTER SHEET
//
// Every control here maps to a parameter the backend already accepts. There is no
// parallel client-side filtering, and no control that does nothing — the two
// failure modes this transformation exists to remove.
//
// Backend contract (GET /parking, GET /parking/bounds):
//   max_price_paise · min_rating · available_only · open_now · open_24_7
//   amenities (comma-separated codes) · radius_m · sort
//
// The sheet edits a LOCAL draft and only commits on Apply, so dragging a slider
// does not fire a request per frame, and Cancel genuinely discards.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/discovery_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../parking/data/parking_repository.dart';

/// Amenity codes seeded by migration 0002. Kept in one place so the sheet cannot
/// offer a filter the backend has no code for.
const _amenities = <(String, String, IconData)>[
  ('covered', 'Covered', Icons.umbrella_rounded),
  ('cctv', 'CCTV', Icons.videocam_rounded),
  ('security', 'Security', Icons.shield_rounded),
  ('ev_charging', 'EV charging', Icons.ev_station_rounded),
  ('valet', 'Valet', Icons.room_service_rounded),
  ('accessible', 'Accessible', Icons.accessible_rounded),
  ('open_24_7', 'Open 24/7', Icons.access_time_rounded),
  ('car_wash', 'Car wash', Icons.local_car_wash_rounded),
  ('lift', 'Lift', Icons.elevator_rounded),
  ('washroom', 'Washroom', Icons.wc_rounded),
];

/// Price ceiling options, in paise. `null` means no limit.
const _priceOptions = <(int?, String)>[
  (null, 'Any'),
  (2000, 'Under ₹20'),
  (4000, 'Under ₹40'),
  (6000, 'Under ₹60'),
  (10000, 'Under ₹100'),
];

/// Radius options, in metres. `null` means no radius constraint.
const _radiusOptions = <(int?, String)>[
  (null, 'Any distance'),
  (1000, 'Within 1 km'),
  (2000, 'Within 2 km'),
  (5000, 'Within 5 km'),
  (10000, 'Within 10 km'),
];

Future<void> showFilterSheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    child: const _FilterSheet(),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  // Draft state, seeded from the live query so reopening the sheet shows exactly
  // what is currently applied.
  late int? _maxPricePaise;
  late double? _minRating;
  late bool _availableOnly;
  late bool _openNow;
  late bool _open24x7;
  late Set<String> _amenityCodes;
  late int? _radiusMetres;
  late ParkingSort _sort;

  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();
    final query = ref.read(discoveryQueryProvider);
    _maxPricePaise = query.maxPricePaise;
    _minRating = query.minRating;
    _availableOnly = query.availableOnly;
    _openNow = query.openNow;
    _open24x7 = query.open24x7;
    _amenityCodes = {...query.amenities};
    _radiusMetres = query.radiusMetres;
    _sort = query.sort;
    _hasLocation = ref.read(locationProvider).hasPosition;
  }

  int get _draftCount {
    var n = 0;
    if (_maxPricePaise != null) n++;
    if (_minRating != null) n++;
    if (_availableOnly) n++;
    if (_openNow) n++;
    if (_open24x7) n++;
    if (_amenityCodes.isNotEmpty) n++;
    if (_radiusMetres != null) n++;
    return n;
  }

  void _reset() {
    setState(() {
      _maxPricePaise = null;
      _minRating = null;
      _availableOnly = false;
      _openNow = false;
      _open24x7 = false;
      _amenityCodes = {};
      _radiusMetres = null;
      _sort = _hasLocation ? ParkingSort.distance : ParkingSort.popularity;
    });
  }

  void _apply() {
    // One commit → one refetch. Both the Home list and the Explore map read the
    // same query provider, so applying here updates both surfaces.
    ref.read(discoveryQueryProvider.notifier).applyFilters(
          maxPricePaise: _maxPricePaise,
          minRating: _minRating,
          availableOnly: _availableOnly,
          openNow: _openNow,
          open24x7: _open24x7,
          amenities: _amenityCodes.toList(),
          radiusMetres: _radiusMetres,
          sort: _sort,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            SheetHeader(
              title: 'Filters',
              actionLabel: _draftCount > 0 ? 'Reset' : null,
              onAction: _draftCount > 0 ? _reset : null,
            ),
            Divider(height: 1, color: context.colors.outline),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageInset,
                  AppSpacing.lg,
                  AppSpacing.pageInset,
                  AppSpacing.xxl,
                ),
                children: [
                  _Group(
                    title: 'Sort by',
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final sort in ParkingSort.values)
                          // Distance sorting is meaningless without a position, so
                          // it is not offered when location is unavailable.
                          if (sort != ParkingSort.distance || _hasLocation)
                            AppFilterChip(
                              label: sort.label,
                              selected: _sort == sort,
                              onTap: () => setState(() => _sort = sort),
                            ),
                      ],
                    ),
                  ),

                  _Group(
                    title: 'Availability',
                    child: Column(
                      children: [
                        _SwitchRow(
                          label: 'Only show parking with free slots',
                          subtitle: 'For the date and time you selected',
                          value: _availableOnly,
                          onChanged: (v) => setState(() => _availableOnly = v),
                        ),
                        _SwitchRow(
                          label: 'Open now',
                          value: _openNow,
                          onChanged: (v) => setState(() => _openNow = v),
                        ),
                        _SwitchRow(
                          label: 'Open 24/7',
                          value: _open24x7,
                          onChanged: (v) => setState(() => _open24x7 = v),
                        ),
                      ],
                    ),
                  ),

                  _Group(
                    title: 'Price',
                    subtitle: 'Hourly rate for your vehicle type',
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final (paise, label) in _priceOptions)
                          AppFilterChip(
                            label: label,
                            selected: _maxPricePaise == paise,
                            onTap: () => setState(() => _maxPricePaise = paise),
                          ),
                      ],
                    ),
                  ),

                  // Distance filtering needs a position; hidden rather than shown
                  // disabled, because a control that cannot work should not appear.
                  if (_hasLocation)
                    _Group(
                      title: 'Distance',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final (metres, label) in _radiusOptions)
                            AppFilterChip(
                              label: label,
                              selected: _radiusMetres == metres,
                              onTap: () => setState(() => _radiusMetres = metres),
                            ),
                        ],
                      ),
                    ),

                  _Group(
                    title: 'Rating',
                    subtitle: 'Only lots that have been reviewed',
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppFilterChip(
                          label: 'Any',
                          selected: _minRating == null,
                          onTap: () => setState(() => _minRating = null),
                        ),
                        for (final r in <double>[3, 4, 4.5])
                          AppFilterChip(
                            label: '${r.toStringAsFixed(r == 4.5 ? 1 : 0)}+',
                            icon: Icons.star_rounded,
                            selected: _minRating == r,
                            onTap: () => setState(() => _minRating = r),
                          ),
                      ],
                    ),
                  ),

                  _Group(
                    title: 'Amenities',
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final (code, label, icon) in _amenities)
                          AppFilterChip(
                            label: label,
                            icon: icon,
                            selected: _amenityCodes.contains(code),
                            onTap: () => setState(() {
                              if (!_amenityCodes.remove(code)) _amenityCodes.add(code);
                            }),
                          ),
                      ],
                    ),
                  ),

                  if (_amenityCodes.length > 1) ...[
                    const SizedBox(height: AppSpacing.md),
                    InlineBanner(
                      message: 'Showing only lots that have all '
                          '${_amenityCodes.length} selected amenities.',
                      icon: Icons.filter_alt_outlined,
                    ),
                  ],
                ],
              ),
            ),

            // Apply bar. Always visible so the commit action is never scrolled away.
            Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(top: BorderSide(color: context.colors.outline)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _draftCount == 0
                              ? 'No filters'
                              : '$_draftCount filter${_draftCount == 1 ? '' : 's'} selected',
                          style: context.text.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      PrimaryButton(
                        label: 'Show results',
                        expand: false,
                        onPressed: _apply,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: context.text.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: context.text.bodyLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!, style: context.text.bodySmall),
                  ],
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// Horizontal strip of currently-applied filters, shown above results so the user
/// can see and remove them without reopening the sheet.
class ActiveFilterBar extends ConsumerWidget {
  const ActiveFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(discoveryQueryProvider);
    final controller = ref.read(discoveryQueryProvider.notifier);

    if (!query.hasFilters) return const SizedBox.shrink();

    final chips = <Widget>[];

    void add(String label, VoidCallback onRemove) {
      chips.add(_RemovableChip(label: label, onRemove: onRemove));
    }

    if (query.maxPricePaise != null) {
      add('Under ${Money(query.maxPricePaise!).display}',
          () => controller.applyFiltersFrom(query, maxPricePaise: null));
    }
    if (query.minRating != null) {
      add('${query.minRating}+ rating',
          () => controller.applyFiltersFrom(query, minRating: null));
    }
    if (query.availableOnly) {
      add('Available', () => controller.applyFiltersFrom(query, availableOnly: false));
    }
    if (query.openNow) {
      add('Open now', () => controller.applyFiltersFrom(query, openNow: false));
    }
    if (query.open24x7) {
      add('24/7', () => controller.applyFiltersFrom(query, open24x7: false));
    }
    if (query.radiusMetres != null) {
      final km = query.radiusMetres! / 1000;
      add('Within ${km % 1 == 0 ? km.toInt() : km} km',
          () => controller.applyFiltersFrom(query, radiusMetres: null));
    }
    for (final code in query.amenities) {
      String amenityLabel = code;
      for (final a in _amenities) {
        if (a.$1 == code) {
          amenityLabel = a.$2;
          break;
        }
      }
      add(amenityLabel, () {
        final next = [...query.amenities]..remove(code);
        controller.applyFiltersFrom(query, amenities: next);
      });
    }

    return SizedBox(
      height: AppSizes.chipHeight + AppSpacing.md,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageInset,
          vertical: AppSpacing.xs,
        ),
        children: [
          for (final chip in chips) ...[chip, const SizedBox(width: AppSpacing.sm)],
          TextButton(
            onPressed: controller.clearFilters,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, AppSizes.chipHeight),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.chipHeight,
      padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: AppRadius.chip,
        border: Border.all(color: AppColors.brand),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: AppColors.brandStrong,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded,
                  size: AppSizes.iconXs, color: AppColors.brandStrong),
            ),
          ),
        ],
      ),
    );
  }
}
