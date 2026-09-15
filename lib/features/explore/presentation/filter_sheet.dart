// ─────────────────────────────────────────────────────────────────────────────
// FILTERS
//
// Everything here maps to a real query parameter the discovery API honours. A
// filter that the server cannot apply is not offered.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/discovery_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/amenity_visuals.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../parking/data/parking_repository.dart';

const _amenityCodes = <String>[
  'covered',
  'ev_charging',
  'cctv',
  'security',
  'accessible',
  'lift',
  'valet',
  'washroom',
  'car_wash',
];

const _priceOptions = <(int?, String)>[
  (null, 'Any price'),
  (2000, 'Under ₹20'),
  (4000, 'Under ₹40'),
  (6000, 'Under ₹60'),
  (10000, 'Under ₹100'),
];

const _radiusOptions = <(int?, String)>[
  (null, 'Any distance'),
  (1000, '1 km'),
  (2000, '2 km'),
  (5000, '5 km'),
  (10000, '10 km'),
];

Future<void> showFilterSheet(BuildContext context) {
  return showAppSheet<void>(context: context, child: const _FilterSheet());
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late int? _maxPricePaise;
  late double? _minRating;
  late bool _availableOnly;
  late bool _openNow;
  late bool _open24x7;
  late Set<String> _amenities;
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
    _amenities = {...query.amenities};
    _radiusMetres = query.radiusMetres;
    _sort = query.sort;
    _hasLocation = ref.read(locationProvider).hasPosition;
  }

  int get _count {
    var n = 0;
    if (_maxPricePaise != null) n++;
    if (_minRating != null) n++;
    if (_availableOnly) n++;
    if (_openNow) n++;
    if (_open24x7) n++;
    if (_amenities.isNotEmpty) n++;
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
      _amenities = {};
      _radiusMetres = null;
      _sort = _hasLocation ? ParkingSort.distance : ParkingSort.popularity;
    });
  }

  void _apply() {
    ref.read(discoveryQueryProvider.notifier).applyFilters(
          maxPricePaise: _maxPricePaise,
          minRating: _minRating,
          availableOnly: _availableOnly,
          openNow: _openNow,
          open24x7: _open24x7,
          amenities: _amenities.toList(),
          radiusMetres: _radiusMetres,
          sort: _sort,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            SheetHeader(
              title: 'Filters',
              actionLabel: _count > 0 ? 'Reset' : null,
              onAction: _count > 0 ? _reset : null,
            ),
            const Hairline(),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                children: [
                  _Group(
                    title: 'Availability',
                    child: Column(
                      children: [
                        _SwitchRow(
                          label: 'Has free spots',
                          subtitle: 'For the time you are booking',
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
                    title: 'Price per hour',
                    child: _ChipWrap(
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
                  if (_hasLocation)
                    _Group(
                      title: 'Distance',
                      child: _ChipWrap(
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
                    subtitle: 'Only places that have been reviewed',
                    child: _ChipWrap(
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
                    subtitle: _amenities.length > 1 ? 'Places with all of these' : null,
                    child: _ChipWrap(
                      children: [
                        for (final code in _amenityCodes)
                          AppFilterChip(
                            label: AmenityVisuals.labelFor(code),
                            icon: AmenityVisuals.iconFor(code),
                            selected: _amenities.contains(code),
                            onTap: () => setState(() {
                              if (!_amenities.remove(code)) _amenities.add(code);
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            BottomActionBar(
              child: PrimaryButton(
                label: _count == 0 ? 'Show results' : 'Show results · $_count filter${_count == 1 ? '' : 's'}',
                onPressed: _apply,
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageInset,
        AppSpacing.xl,
        AppSpacing.pageInset,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: context.text.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: children);
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
                  if (subtitle != null) Text(subtitle!, style: context.text.bodySmall),
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
