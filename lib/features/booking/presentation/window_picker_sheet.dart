// ─────────────────────────────────────────────────────────────────────────────
// WHEN
//
// Arrival (now or a chosen time) and how long. The server re-checks every spot
// for the new window; nothing here decides availability.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/interaction.dart';

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

  static const _durations = <int>[30, 60, 120, 180, 240, 480, 720, 1440];

  bool get _isNow => _start.difference(DateTime.now()).inMinutes.abs() < 2;

  @override
  Widget build(BuildContext context) {
    final options = _durations.where((m) => m <= widget.maxDurationMinutes).toList();
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'When do you need it?'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Option(
                  icon: Icons.bolt_rounded,
                  title: 'Now',
                  subtitle: 'Park straight away',
                  selected: _isNow,
                  onTap: () => setState(() => _start = DateTime.now()),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Option(
                  icon: Icons.event_outlined,
                  title: 'Schedule',
                  subtitle: _isNow
                      ? 'Choose a date and time'
                      : DateFormat('EEE d MMM, h:mm a').format(_start),
                  selected: !_isNow,
                  onTap: _pickDateTime,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('How long', style: context.text.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final minutes in options)
                      AppFilterChip(
                        label: _durationLabel(minutes),
                        selected: _duration == minutes,
                        onTap: () => setState(() => _duration = minutes),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: AppSizes.iconSm, color: AppColors.inkSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(_windowSentence(), style: context.text.bodyLarge)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Show spots',
                  onPressed: () => Navigator.of(context).pop(
                    WindowSelection(startAt: _start, durationMinutes: _duration),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
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
    if (chosen.isBefore(now.subtract(const Duration(minutes: 5)))) {
      if (!mounted) return;
      showToast(context, 'Pick a time in the future.');
      return;
    }
    setState(() => _start = chosen);
  }

  String _windowSentence() {
    final end = _start.add(Duration(minutes: _duration));
    final sameDay = _start.day == end.day && _start.month == end.month;
    final startLabel = _isNow ? 'Now' : DateFormat('EEE d MMM, h:mm a').format(_start);
    final endLabel =
        sameDay ? DateFormat('h:mm a').format(end) : DateFormat('EEE d MMM, h:mm a').format(end);
    return '$startLabel – $endLabel';
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

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      feedback: PressFeedback.selection,
      depth: PressDepth.subtle,
      borderRadius: AppRadius.card,
      semanticLabel: '$title, $subtitle',
      child: AnimatedContainer(
        duration: AppMotion.instant,
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.lineStrong,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            IconDisc(icon: icon, size: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleMedium),
                  Text(subtitle, style: context.text.bodyMedium),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? AppColors.ink : AppColors.inkDisabled,
            ),
          ],
        ),
      ),
    );
  }
}
