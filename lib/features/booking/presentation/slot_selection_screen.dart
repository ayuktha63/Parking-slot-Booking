// ─────────────────────────────────────────────────────────────────────────────
// CHOOSE A SPOT
//
// The lot's real floor plan for the chosen time, updating live as other people
// hold and book spots. Picking a spot and continuing places a short server-side
// hold, so nobody else can take it while the booking is reviewed.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/booking_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../shared/models/availability.dart';
import '../../../shared/models/parking.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/interaction.dart';
import '../../../shared/widgets/parqx_controls.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/surfaces.dart';
import 'hold_countdown_bar.dart';
import 'window_picker_sheet.dart';

class SlotSelectionScreen extends ConsumerStatefulWidget {
  const SlotSelectionScreen({
    super.key,
    required this.parkingId,
    required this.parkingName,
    required this.vehicleType,
    required this.startAt,
    required this.durationMinutes,
  });

  final int parkingId;
  final String parkingName;
  final VehicleType vehicleType;
  final DateTime startAt;
  final int durationMinutes;

  @override
  ConsumerState<SlotSelectionScreen> createState() => _SlotSelectionScreenState();
}

class _SlotSelectionScreenState extends ConsumerState<SlotSelectionScreen> {
  late final BookingDraftSeed _seed = BookingDraftSeed(
    parkingAreaId: widget.parkingId,
    vehicleType: widget.vehicleType,
    startAt: widget.startAt,
    durationMinutes: widget.durationMinutes,
  );

  bool _isHolding = false;

  /// "Now" is a mode, not a timestamp. A customer who opens the plan and takes
  /// four minutes to choose is still parking now — the hold starts when they
  /// commit, not when the screen opened.
  late bool _nowMode = widget.startAt.difference(DateTime.now()).inMinutes.abs() < 2;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider(_seed));
    final layout = ref.watch(liveSlotLayoutProvider(draft));
    final hold = ref.watch(holdControllerProvider);

    ref.listen(holdControllerProvider, (previous, next) {
      if (next.expiredJustNow && mounted) {
        ref.read(bookingDraftProvider(_seed).notifier).selectSlot(null);
        ref.invalidate(slotLayoutProvider(draft));
        showToast(
          context,
          'Your hold ran out and the spot was released. Pick a spot to try again.',
          duration: const Duration(seconds: 4),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a spot', style: context.text.titleLarge),
            Text(
              widget.parkingName,
              style: context.text.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (hold.hasHold)
            HoldCountdownBar(
              state: hold,
              onExtend: hold.hold?.canExtend == true
                  ? () => ref.read(holdControllerProvider.notifier).extend()
                  : null,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageInset,
              AppSpacing.sm,
              AppSpacing.pageInset,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(child: _WindowPill(draft: draft, nowMode: _nowMode, onTap: _editWindow)),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 132,
                  child: Segmented<VehicleType>(
                    value: draft.vehicleType,
                    semanticLabel: 'Vehicle type',
                    onChanged: (type) =>
                        ref.read(bookingDraftProvider(_seed).notifier).setVehicleType(type),
                    options: const [
                      SegmentOption(value: VehicleType.car, label: 'Car'),
                      SegmentOption(value: VehicleType.bike, label: 'Bike'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Hairline(),
          Expanded(
            child: layout.when(
              loading: () => const _LayoutSkeleton(),
              error: (error, _) => ErrorStateView(
                error: asApiException(error),
                onRetry: () => ref.invalidate(slotLayoutProvider(draft)),
              ),
              data: (data) => _FloorPlan(
                layout: data,
                selectedSlotId: draft.selectedSlotId,
                onSelect: _onSlotTapped,
                onRefresh: () async => ref.invalidate(slotLayoutProvider(draft)),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _SelectionBar(
        draft: draft,
        layout: layout.valueOrNull,
        isHolding: _isHolding,
        onContinue: _continue,
      ),
    );
  }

  /* ── actions ───────────────────────────────────────────────────────────── */

  Future<void> _editWindow() async {
    final draft = ref.read(bookingDraftProvider(_seed));
    final result = await showAppSheet<WindowSelection>(
      context: context,
      child: WindowPickerSheet(startAt: draft.startAt, durationMinutes: draft.durationMinutes),
    );
    if (result == null || !mounted) return;
    // A hold is for one window; a new window starts clean.
    if (ref.read(holdControllerProvider).hasHold) {
      await ref.read(holdControllerProvider.notifier).release();
    }
    setState(() => _nowMode = result.startAt.difference(DateTime.now()).inMinutes.abs() < 2);
    ref.read(bookingDraftProvider(_seed).notifier).setWindow(
          startAt: result.startAt,
          durationMinutes: result.durationMinutes,
        );
  }

  void _onSlotTapped(ParkingSlot slot) {
    if (!slot.isSelectable) {
      Haptics.refusal();
      _explainUnavailable(slot);
      return;
    }
    final controller = ref.read(bookingDraftProvider(_seed).notifier);
    final current = ref.read(bookingDraftProvider(_seed)).selectedSlotId;
    if (current == slot.id) {
      Haptics.light();
      controller.selectSlot(null);
      if (ref.read(holdControllerProvider).hasHold) {
        ref.read(holdControllerProvider.notifier).release();
      }
      return;
    }
    Haptics.selection();
    controller.selectSlot(slot.id);
  }

  void _explainUnavailable(ParkingSlot slot) {
    final message = switch (slot.status) {
      SlotStatus.booked => 'Spot ${slot.code} is booked for this time.',
      SlotStatus.held => 'Someone is booking spot ${slot.code} right now.',
      SlotStatus.closed => slot.closedReason == null
          ? 'Spot ${slot.code} is out of service.'
          : 'Spot ${slot.code} is out of service: ${slot.closedReason}',
      SlotStatus.available => 'Spot ${slot.code} is free.',
    };
    showToast(context, message, duration: const Duration(seconds: 2));
  }

  Future<void> _continue() async {
    final draft = ref.read(bookingDraftProvider(_seed));
    if (!draft.canHold) return;

    setState(() => _isHolding = true);
    final existing = ref.read(holdControllerProvider).hold;
    var ok = true;
    if (existing == null || existing.slot.id != draft.selectedSlotId) {
      ok = await ref.read(holdControllerProvider.notifier).take(
            parkingAreaId: draft.parkingAreaId,
            slotId: draft.selectedSlotId!,
            startAt: _nowMode ? DateTime.now() : draft.startAt,
            durationMinutes: draft.durationMinutes,
          );
    }
    if (!mounted) return;
    setState(() => _isHolding = false);

    if (!ok) {
      Haptics.refusal();
      final error = ref.read(holdControllerProvider).error;
      ref.invalidate(slotLayoutProvider(draft));
      ref.read(bookingDraftProvider(_seed).notifier).selectSlot(null);
      showToast(context, error?.message ?? 'That spot was just taken. Pick another.');
      return;
    }

    Haptics.success();
    context.push(Routes.bookingReview);
  }
}

/* ── window pill ───────────────────────────────────────────────────────────── */

class _WindowPill extends StatelessWidget {
  const _WindowPill({required this.draft, required this.nowMode, required this.onTap});

  final BookingDraft draft;
  final bool nowMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = draft.startAt;
    final isNow = nowMode;
    final isToday = start.year == now.year && start.month == now.month && start.day == now.day;
    final when = isNow
        ? 'Now'
        : isToday
            ? DateFormat('h:mm a').format(start)
            : DateFormat('EEE d MMM, h:mm a').format(start);
    return Pressable(
      onTap: onTap,
      depth: PressDepth.subtle,
      tint: false,
      borderRadius: AppRadius.chip,
      semanticLabel: 'Parking from $when for ${_duration(draft.durationMinutes)}. Change',
      child: Container(
        height: AppSizes.chipHeight + 4,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
        decoration: const BoxDecoration(color: AppColors.fill, borderRadius: AppRadius.chip),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, size: AppSizes.iconSm, color: AppColors.ink),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '$when · ${_duration(draft.durationMinutes)}',
                style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: AppSizes.iconMd),
          ],
        ),
      ),
    );
  }

  static String _duration(int minutes) {
    if (minutes % 60 == 0) {
      final h = minutes ~/ 60;
      return '$h hr${h == 1 ? '' : 's'}';
    }
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }
}

/* ── floor plan ────────────────────────────────────────────────────────────── */

const double _gap = 8;

class _FloorPlan extends StatelessWidget {
  const _FloorPlan({
    required this.layout,
    required this.selectedSlotId,
    required this.onSelect,
    required this.onRefresh,
  });

  final SlotLayout layout;
  final int? selectedSlotId;
  final ValueChanged<ParkingSlot> onSelect;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (layout.isEmpty) {
      final noun = layout.vehicleType == VehicleType.car ? 'car' : 'bike';
      return EmptyStateView(
        title: 'No $noun spots here',
        message: 'This place has no $noun spots set up. Try the other vehicle type, '
            'or another place.',
        icon: Icons.grid_off_rounded,
      );
    }

    final widest = layout.rows.fold<int>(1, (m, r) => r.slots.length > m ? r.slots.length : m);
    const labelWidth = 28.0;
    final available = context.screenWidth - AppSpacing.pageInset * 2 - AppSpacing.lg * 2;
    // Fit the widest row on screen while a spot stays comfortably tappable;
    // only very wide rows fall back to scrolling sideways.
    final fitted = (available - labelWidth - (widest - 1) * _gap) / widest;
    final spotWidth = fitted >= 44 ? math.min(fitted, 64.0) : AppSizes.spotWidth;
    final spotHeight = spotWidth * 1.28;
    final contentWidth = labelWidth + widest * spotWidth + (widest - 1) * _gap;
    final planWidth = math.max(contentWidth, available);

    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageInset,
          AppSpacing.lg,
          AppSpacing.pageInset,
          AppSpacing.xxxl,
        ),
        children: [
          if (!layout.window.isOpen) ...[
            const InlineBanner(
              message: 'This place is closed at the time you picked. Change the time to book.',
              tone: BannerTone.warning,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          _AvailabilityLine(summary: layout.liveSummary),
          const SizedBox(height: AppSpacing.md),
          AppSurface(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: planWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < layout.rows.length; i++) ...[
                      _RowOfSpots(
                        row: layout.rows[i],
                        selectedSlotId: selectedSlotId,
                        onSelect: onSelect,
                        vehicleType: layout.vehicleType,
                        labelWidth: labelWidth,
                        spotWidth: spotWidth,
                        spotHeight: spotHeight,
                      ),
                      if (i < layout.rows.length - 1) const _Aisle(),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    const _Entrance(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _Legend(),
        ],
      ),
    );
  }
}

class _AvailabilityLine extends StatelessWidget {
  const _AvailabilityLine({required this.summary});

  final AvailabilitySummary summary;

  @override
  Widget build(BuildContext context) {
    final free = summary.available;
    final (String text, Color dot, Color ink) = switch (free) {
      0 => ('No spots free for this time', AppColors.negative, AppColors.negative),
      1 => ('1 spot left', AppColors.warningBright, AppColors.warning),
      _ when free <= 3 => ('$free spots left', AppColors.warningBright, AppColors.warning),
      _ => ('$free of ${summary.total} spots free', AppColors.positiveBright, AppColors.positive),
    };
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.text.titleSmall?.copyWith(color: ink),
          ),
        ),
        if (summary.held > 0)
          Text('${summary.held} being booked', style: context.text.bodySmall),
      ],
    );
  }
}

class _RowOfSpots extends StatelessWidget {
  const _RowOfSpots({
    required this.row,
    required this.selectedSlotId,
    required this.onSelect,
    required this.vehicleType,
    required this.labelWidth,
    required this.spotWidth,
    required this.spotHeight,
  });

  final SlotRow row;
  final int? selectedSlotId;
  final ValueChanged<ParkingSlot> onSelect;
  final VehicleType vehicleType;
  final double labelWidth;
  final double spotWidth;
  final double spotHeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(row.label, style: AppTypography.code(size: 14, color: AppColors.inkTertiary)),
        ),
        for (var i = 0; i < row.slots.length; i++)
          Padding(
            padding: EdgeInsets.only(right: i == row.slots.length - 1 ? 0 : _gap),
            child: _Spot(
              slot: row.slots[i],
              isSelected: row.slots[i].id == selectedSlotId,
              vehicleType: vehicleType,
              width: spotWidth,
              height: spotHeight,
              onTap: () => onSelect(row.slots[i]),
            ),
          ),
      ],
    );
  }
}

class _Spot extends StatelessWidget {
  const _Spot({
    required this.slot,
    required this.isSelected,
    required this.vehicleType,
    required this.onTap,
    required this.width,
    required this.height,
  });

  final ParkingSlot slot;
  final bool isSelected;
  final VehicleType vehicleType;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final look = _spotLook(slot, selected: isSelected, vehicleType: vehicleType);
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: slot.isSelectable,
      label: 'Spot ${slot.code}, ${isSelected ? 'selected' : slot.status.label}'
          '${slot.slotClass.isSpecial ? ', ${slot.slotClass.label}' : ''}',
      // Restated here: excludeSemantics also removes the detector's tap action.
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: isSelected ? 1.06 : 1,
          duration: AppMotion.quick,
          curve: AppMotion.spring,
          child: AnimatedContainer(
            duration: AppMotion.quick,
            curve: AppMotion.standard,
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: look.fill,
              borderRadius: AppRadius.tile,
              border: look.line == null ? null : Border.all(color: look.line!, width: 1.5),
              boxShadow: isSelected
                  ? const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))]
                  : AppShadows.none,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(look.icon, size: 18, color: look.iconColor),
                const SizedBox(height: 4),
                Text(slot.code, style: AppTypography.code(size: 12.5, color: look.ink)),
                if (slot.slotClass.isSpecial)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(_classIcon(slot.slotClass), size: 11, color: look.iconColor),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _classIcon(SlotClass slotClass) {
    switch (slotClass) {
      case SlotClass.accessible:
        return Icons.accessible_rounded;
      case SlotClass.ev:
        return Icons.ev_station_rounded;
      case SlotClass.compact:
        return Icons.compress_rounded;
      case SlotClass.valet:
        return Icons.room_service_rounded;
      case SlotClass.standard:
        return Icons.circle;
    }
  }
}

class _SpotLook {
  const _SpotLook({
    required this.fill,
    required this.ink,
    required this.icon,
    required this.iconColor,
    this.line,
  });

  final Color fill;
  final Color? line;
  final Color ink;
  final IconData icon;
  final Color iconColor;
}

_SpotLook _spotLook(ParkingSlot slot, {required bool selected, required VehicleType vehicleType}) {
  final vehicleIcon =
      vehicleType == VehicleType.bike ? Icons.two_wheeler_rounded : Icons.directions_car_outlined;
  if (selected) {
    return const _SpotLook(
      fill: AppColors.spotSelected,
      ink: AppColors.onInk,
      icon: Icons.check_rounded,
      iconColor: AppColors.onInk,
    );
  }
  switch (slot.status) {
    case SlotStatus.available:
      return _SpotLook(
        fill: AppColors.spotFree,
        line: AppColors.spotFreeLine,
        ink: AppColors.ink,
        icon: vehicleIcon,
        iconColor: AppColors.inkDisabled,
      );
    case SlotStatus.held:
      return slot.heldByYou
          ? const _SpotLook(
              fill: AppColors.spotYours,
              line: AppColors.accent,
              ink: AppColors.accent,
              icon: Icons.lock_clock_outlined,
              iconColor: AppColors.accent,
            )
          : const _SpotLook(
              fill: AppColors.spotHeld,
              line: AppColors.spotHeldLine,
              ink: AppColors.warning,
              icon: Icons.hourglass_top_rounded,
              iconColor: AppColors.warning,
            );
    case SlotStatus.booked:
      return _SpotLook(
        fill: AppColors.spotBooked,
        ink: AppColors.inkDisabled,
        icon: vehicleType == VehicleType.bike ? Icons.two_wheeler_rounded : Icons.directions_car_filled_rounded,
        iconColor: AppColors.inkDisabled,
      );
    case SlotStatus.closed:
      return const _SpotLook(
        fill: AppColors.spotClosed,
        line: AppColors.line,
        ink: AppColors.inkDisabled,
        icon: Icons.block_rounded,
        iconColor: AppColors.inkDisabled,
      );
  }
}

class _Aisle extends StatelessWidget {
  const _Aisle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: CustomPaint(
        size: const Size(double.infinity, 2),
        painter: _DashPainter(),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.lineStrong
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    var x = 28.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1), Offset((x + 10).clamp(0, size.width), 1), paint);
      x += 18;
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}

class _Entrance extends StatelessWidget {
  const _Entrance();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 28),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          decoration: const BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.chip),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.inkSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text('Entrance', style: AppTypography.overline(color: AppColors.inkSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget swatch(Color fill, Color? line) => Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            border: line == null ? null : Border.all(color: line, width: 1.5),
          ),
        );
    final entries = <(Widget, String)>[
      (swatch(AppColors.spotFree, AppColors.spotFreeLine), 'Free'),
      (swatch(AppColors.spotSelected, null), 'Selected'),
      (swatch(AppColors.spotHeld, AppColors.spotHeldLine), 'Being booked'),
      (swatch(AppColors.spotBooked, null), 'Taken'),
    ];
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: [
        for (final (sw, label) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [sw, const SizedBox(width: AppSpacing.sm), Text(label, style: context.text.bodyMedium)],
          ),
      ],
    );
  }
}

/* ── selection bar ─────────────────────────────────────────────────────────── */

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.draft,
    required this.layout,
    required this.isHolding,
    required this.onContinue,
  });

  final BookingDraft draft;
  final SlotLayout? layout;
  final bool isHolding;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final selected = draft.selectedSlotId == null ? null : layout?.findById(draft.selectedSlotId!);
    final row = selected != null && RegExp(r'^[A-Za-z]').hasMatch(selected.code)
        ? 'Row ${selected.code[0].toUpperCase()}'
        : null;

    return BottomActionBar(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selected == null ? 'Pick a spot' : 'Spot ${selected.code}',
                  style: context.text.headlineSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  selected == null
                      ? 'Tap any free spot on the plan'
                      : [if (row != null) row, selected.slotClass.label ?? 'Standard spot'].join(' · '),
                  style: context.text.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          PrimaryButton(
            label: 'Continue',
            expand: false,
            isLoading: isHolding,
            onPressed: selected == null ? null : onContinue,
          ),
        ],
      ),
    );
  }
}

/* ── skeleton ──────────────────────────────────────────────────────────────── */

class _LayoutSkeleton extends StatelessWidget {
  const _LayoutSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageInset),
      children: [
        const LoadingSkeleton.text(width: 160),
        const SizedBox(height: AppSpacing.lg),
        for (var row = 0; row < 3; row++) ...[
          const Row(
            children: [
              SizedBox(width: 28),
              LoadingSkeleton(width: AppSizes.spotWidth, height: AppSizes.spotHeight),
              SizedBox(width: _gap),
              LoadingSkeleton(width: AppSizes.spotWidth, height: AppSizes.spotHeight),
              SizedBox(width: _gap),
              LoadingSkeleton(width: AppSizes.spotWidth, height: AppSizes.spotHeight),
              SizedBox(width: _gap),
              LoadingSkeleton(width: AppSizes.spotWidth, height: AppSizes.spotHeight),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ],
    );
  }
}
