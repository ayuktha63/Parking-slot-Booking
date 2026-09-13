// ─────────────────────────────────────────────────────────────────────────────
// WHEN AND HOW LONG
//
// One sheet for both halves of the window, because they are one decision.
//
// The constraints it enforces — no start in the past, nothing beyond the booking
// horizon — mirror the server's, so the customer is told immediately rather than
// after a round trip. The server still enforces them; this is courtesy, not
// authority.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';

/// What the sheet returns.
class WindowSelection {
  const WindowSelection({required this.startAt, required this.durationMinutes});

  final DateTime startAt;
  final int durationMinutes;
}

class WindowPickerSheet extends StatefulWidget {
  const WindowPickerSheet({
    super.key,
    required this.startAt,
    required this.durationMinutes,
    this.maxAdvanceDays = 30,
    this.maxDurationMinutes = 24 * 60,
  });

  final DateTime startAt;
  final int durationMinutes;
  final int maxAdvanceDays;
  final int maxDurationMinutes;

  @override
  State<WindowPickerSheet> createState() => _WindowPickerSheetState();
}

class _WindowPickerSheetState extends State<WindowPickerSheet> {
  late DateTime _start = widget.startAt;
  late int _duration = widget.durationMinutes;

  /// The durations people actually book. Free entry is not offered because the
  /// server bills per started hour anyway — a 47-minute choice would be billed as
  /// an hour, which is the kind of surprise this screen exists to avoid.
  static const _durations = <int>[30, 60, 120, 180, 240, 480, 720, 1440];

  bool get _isNow => _start.difference(DateTime.now()).inMinutes.abs() < 2;

  @override
  Widget build(BuildContext context) {
    final tooLong = _duration > widget.maxDurationMinutes;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.sheet,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHeader(title: 'When do you need parking?'),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageInset,
                0,
                AppSpacing.pageInset,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Arriving',
                      style:
                          context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.sm),

                  Row(
                    children: [
                      Expanded(
                        child: _ChoiceTile(
                          label: 'Now',
                          detail: 'Park straight away',
                          selected: _isNow,
                          onTap: () => setState(() => _start = DateTime.now()),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _ChoiceTile(
                          label: 'Later',
                          detail: _isNow
                              ? 'Pick a date and time'
                              : DateFormat('EEE d MMM, h:mm a').format(_start),
                          selected: !_isNow,
                          onTap: _pickDateTime,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  Text('For how long',
                      style:
                          context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.sm),

                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _durations
                        .where((m) => m <= widget.maxDurationMinutes)
                        .map((minutes) => AppFilterChip(
                              label: _durationLabel(minutes),
                              selected: _duration == minutes,
                              onTap: () => setState(() => _duration = minutes),
                            ))
                        .toList(growable: false),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // The window in words, so there is no ambiguity about what is
                  // being booked before money is involved.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceContainerHighest,
                      borderRadius: AppRadius.field,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_available_rounded,
                            size: AppSizes.iconSm, color: AppColors.brand),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _windowSentence(),
                            style: context.text.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (tooLong) ...[
                    const SizedBox(height: AppSpacing.md),
                    InlineBanner(
                      message: 'This parking area allows stays up to '
                          '${_durationLabel(widget.maxDurationMinutes)}.',
                      tone: BannerTone.warning,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),

                  PrimaryButton(
                    label: 'Show slots',
                    onPressed: tooLong
                        ? null
                        : () => Navigator.of(context).pop(
                              WindowSelection(startAt: _start, durationMinutes: _duration),
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: _start.isBefore(now) ? now : _start,
      firstDate: now,
      lastDate: now.add(Duration(days: widget.maxAdvanceDays)),
      helpText: 'Arrival date',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start.isBefore(now) ? now : _start),
      helpText: 'Arrival time',
    );
    if (time == null || !mounted) return;

    final chosen = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    // Choosing a time earlier today would be rejected by the server; say so here
    // instead of letting them press on and be refused.
    if (chosen.isBefore(now.subtract(const Duration(minutes: 5)))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Pick a time in the future.')));
      return;
    }

    setState(() => _start = chosen);
  }

  String _windowSentence() {
    final end = _start.add(Duration(minutes: _duration));
    final sameDay = _start.day == end.day && _start.month == end.month;

    final startLabel = _isNow
        ? 'Now'
        : DateFormat('EEE d MMM, h:mm a').format(_start);
    final endLabel = sameDay
        ? DateFormat('h:mm a').format(end)
        : DateFormat('EEE d MMM, h:mm a').format(end);

    return '$startLabel → $endLabel';
  }

  static String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    if (minutes == 1440) return '1 day';
    if (minutes % 60 == 0) {
      final h = minutes ~/ 60;
      return '$h hr${h == 1 ? '' : 's'}';
    }
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.field,
        child: AnimatedContainer(
          duration: AppMotion.instant,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandSoft : context.colors.surface,
            border: Border.all(
              color: selected ? AppColors.brand : context.colors.outline,
              width: selected ? 2 : 1,
            ),
            borderRadius: AppRadius.field,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.brandStrong : context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
