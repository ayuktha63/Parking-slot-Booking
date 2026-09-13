// ─────────────────────────────────────────────────────────────────────────────
// SLOT & TIME
//
// The seat-selection moment, for parking.
//
// The layout drawn here is the REAL one: `row_label` and `position` come from
// `parking_slots`, which an operator configures. The old app invented lanes with
// `slot_number <= 6 ? 'A' : 'B'`, so a 40-slot lot showed 6 tiles in lane A and 34
// in lane B — a picture that corresponded to nothing a driver would find on arrival.
//
// Every state a tile can be in comes from the server's `status` field, and the four
// colours are the shared slot tokens, so a held slot looks the same here as it does
// on the operator's grid.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/booking_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import 'journey_progress.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/availability.dart';
import '../../../shared/models/parking.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
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

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider(_seed));
    // The live view: the same layout, patched by slot events as they arrive, so a
    // slot taken by someone else turns amber under the customer's finger instead
    // of being refused at the end of checkout.
    final layout = ref.watch(liveSlotLayoutProvider(draft));
    final hold = ref.watch(holdControllerProvider);

    // A hold that lapsed while this screen was open: drop the selection and say so,
    // rather than leaving a slot highlighted that is no longer reserved.
    ref.listen(holdControllerProvider, (previous, next) {
      if (next.expiredJustNow && mounted) {
        ref.read(bookingDraftProvider(_seed).notifier).selectSlot(null);
        ref.invalidate(slotLayoutProvider(draft));
        _showHoldExpired();
      }
    });

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a slot', style: context.text.titleMedium),
            Text(
              widget.parkingName,
              style:
                  context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        titleSpacing: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(9),
          child: JourneyProgress(step: BookingStep.slot),
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
          _WindowBar(
            draft: draft,
            onEdit: _editWindow,
            onVehicleChanged: (type) =>
                ref.read(bookingDraftProvider(_seed).notifier).setVehicleType(type),
          ),
          Expanded(
            child: layout.when(
              loading: () => const _LayoutSkeleton(),
              error: (error, _) => ErrorStateView(
                error: asApiException(error),
                onRetry: () => ref.invalidate(slotLayoutProvider(draft)),
              ),
              data: (data) => _SlotLayoutView(
                layout: data,
                selectedSlotId: draft.selectedSlotId,
                onSelect: _onSlotTapped,
                onRefresh: () async => ref.invalidate(slotLayoutProvider(draft)),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        draft: draft,
        layout: layout.valueOrNull,
        isHolding: _isHolding,
        onContinue: _continue,
      ),
    );
  }

  /* ── actions ─────────────────────────────────────────────────────────── */

  Future<void> _editWindow() async {
    final draft = ref.read(bookingDraftProvider(_seed));

    final result = await showModalBottomSheet<WindowSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WindowPickerSheet(
        startAt: draft.startAt,
        durationMinutes: draft.durationMinutes,
      ),
    );

    if (result == null || !mounted) return;

    // Changing the window invalidates any hold: it was taken for the old one.
    if (ref.read(holdControllerProvider).hasHold) {
      await ref.read(holdControllerProvider.notifier).release();
    }

    ref.read(bookingDraftProvider(_seed).notifier).setWindow(
          startAt: result.startAt,
          durationMinutes: result.durationMinutes,
        );
  }

  void _onSlotTapped(ParkingSlot slot) {
    if (!slot.isSelectable) {
      // A refusal you can feel. The driver is often looking at the car park, not
      // the phone; the snackbar alone is easy to miss.
      Haptics.refusal();
      _explainUnavailable(slot);
      return;
    }

    final controller = ref.read(bookingDraftProvider(_seed).notifier);
    final current = ref.read(bookingDraftProvider(_seed)).selectedSlotId;

    // Tapping the selected slot again deselects it — and gives the hold back,
    // because continuing to hold a slot nobody has selected is not honest.
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

  /// Says why a tile cannot be chosen. Silence on a tap reads as a broken button.
  void _explainUnavailable(ParkingSlot slot) {
    final message = switch (slot.status) {
      SlotStatus.booked =>
        'Slot ${slot.code} is booked for this time. Try another time or slot.',
      SlotStatus.held => 'Someone is booking slot ${slot.code} right now.',
      SlotStatus.closed => slot.closedReason == null
          ? 'Slot ${slot.code} is out of service.'
          : 'Slot ${slot.code} is out of service: ${slot.closedReason}',
      SlotStatus.available => 'Slot ${slot.code} is available.',
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  /// Takes the hold, then moves on. The hold is taken HERE rather than on the
  /// review screen so the slot is genuinely reserved before the customer starts
  /// entering details — which is the whole point of a hold.
  Future<void> _continue() async {
    final draft = ref.read(bookingDraftProvider(_seed));
    if (!draft.canHold) return;

    setState(() => _isHolding = true);

    final existing = ref.read(holdControllerProvider).hold;
    var ok = true;

    // Re-holding the same slot is wasteful; the server would reissue it anyway.
    if (existing == null || existing.slot.id != draft.selectedSlotId) {
      ok = await ref.read(holdControllerProvider.notifier).take(
            parkingAreaId: draft.parkingAreaId,
            slotId: draft.selectedSlotId!,
            startAt: draft.startAt,
            durationMinutes: draft.durationMinutes,
          );
    }

    if (!mounted) return;
    setState(() => _isHolding = false);

    if (!ok) {
      Haptics.refusal();
      final error = ref.read(holdControllerProvider).error;
      // Someone else got there first. Refresh so the tile turns amber/grey
      // immediately rather than staying green and lying.
      ref.invalidate(slotLayoutProvider(draft));
      ref.read(bookingDraftProvider(_seed).notifier).selectSlot(null);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(error?.message ?? 'That slot is no longer available.'),
        ));
      return;
    }

    if (!mounted) return;
    // The slot is genuinely reserved now — the one commitment on this screen.
    Haptics.success();
    context.push(Routes.bookingReview);
  }

  void _showHoldExpired() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content:
            Text('Your hold expired and the slot was released. Pick a slot to try again.'),
        duration: Duration(seconds: 4),
      ));
  }
}

/* ── window + vehicle ──────────────────────────────────────────────────────── */

class _WindowBar extends StatelessWidget {
  const _WindowBar({
    required this.draft,
    required this.onEdit,
    required this.onVehicleChanged,
  });

  final BookingDraft draft;
  final VoidCallback onEdit;
  final ValueChanged<VehicleType> onVehicleChanged;

  @override
  Widget build(BuildContext context) {
    final start = DateFormat('EEE d MMM, h:mm a').format(draft.startAt);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageInset,
        AppSpacing.md,
        AppSpacing.pageInset,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.outline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onEdit,
              borderRadius: AppRadius.field,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: AppSizes.iconSm, color: context.colors.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(start,
                              style: context.text.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(
                            _durationLabel(draft.durationMinutes),
                            style: context.text.bodySmall
                                ?.copyWith(color: context.colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_calendar_outlined,
                        size: AppSizes.iconSm, color: AppColors.brand),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _VehicleToggle(selected: draft.vehicleType, onChanged: onVehicleChanged),
        ],
      ),
    );
  }

  static String _durationLabel(int minutes) {
    if (minutes % 60 == 0) {
      final h = minutes ~/ 60;
      return 'for $h hour${h == 1 ? '' : 's'}';
    }
    if (minutes < 60) return 'for $minutes min';
    return 'for ${minutes ~/ 60}h ${minutes % 60}m';
  }
}

class _VehicleToggle extends StatelessWidget {
  const _VehicleToggle({required this.selected, required this.onChanged});

  final VehicleType selected;
  final ValueChanged<VehicleType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: VehicleType.values.map((type) {
          final isSelected = type == selected;
          return Semantics(
            selected: isSelected,
            button: true,
            label: type == VehicleType.car ? 'Car' : 'Bike',
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: AppMotion.instant,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brand : Colors.transparent,
                  borderRadius: AppRadius.chip,
                ),
                child: Icon(
                  type == VehicleType.car
                      ? Icons.directions_car_rounded
                      : Icons.two_wheeler_rounded,
                  size: AppSizes.iconSm,
                  color: isSelected ? AppColors.onBrand : context.colors.onSurfaceVariant,
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

/// Gap between bays. Tight on purpose — bays in a real car park are adjacent,
/// and the spacing is what decides whether a row fits a narrow screen.
const double _bayGap = 6;

/// Softens the trailing edge of a horizontally overflowing plan.
class _FadeTrailingEdge extends StatelessWidget {
  const _FadeTrailingEdge({required this.child, required this.active});

  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;

    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        stops: [0.0, 0.88, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

/* ── the layout ────────────────────────────────────────────────────────────── */

class _SlotLayoutView extends StatelessWidget {
  const _SlotLayoutView({
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
      return EmptyStateView(
        title: 'No slots configured',
        message:
            'This parking area has no ${layout.vehicleType == VehicleType.car ? 'car' : 'bike'} '
            'slots set up yet. Try the other vehicle type, or another parking area.',
        icon: Icons.grid_off_rounded,
      );
    }

    final summary = layout.summary;

    // The plan is at least as wide as the panel, and wider when a row of bays
    // overflows it. Computed rather than assumed, because the aisle and the
    // entrance marker have to span the same width as the widest row inside a
    // viewport that imposes no width of its own.
    final widestRow = layout.rows.fold<int>(
      0,
      (max, row) => row.slots.length > max ? row.slots.length : max,
    );
    const rowLabelWidth = 22 + AppSpacing.sm;
    // `_bayGap` rather than `AppSpacing.sm`: the difference is what lets a
    // five-bay row fit a 360px screen instead of clipping the last bay behind
    // the panel edge, which read as a rendering fault rather than as "scroll me".
    final contentWidth = rowLabelWidth + widestRow * (AppSizes.slotTileWidth + _bayGap);
    final panelWidth = context.screenWidth - AppSpacing.pageInset * 2 - AppSpacing.md * 2;
    final planWidth = contentWidth > panelWidth ? contentWidth : panelWidth;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageInset,
          AppSpacing.lg,
          AppSpacing.pageInset,
          AppSpacing.xxxl,
        ),
        children: [
          // Closed for this window. Said here, before a slot is chosen, rather
          // than letting the server refuse the hold afterwards.
          if (!layout.window.isOpen) ...[
            const InlineBanner(
              message: 'This parking area is closed at the time you selected. '
                  'Change the time to book.',
              tone: BannerTone.warning,
              icon: Icons.schedule_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          _AvailabilityLine(summary: summary),
          const SizedBox(height: AppSpacing.lg),

          // ── the floor plan ──────────────────────────────────────────
          //
          // A dark tarmac surface with the bays painted onto it. The dark panel
          // is doing real work, not decoration: an open bay is drawn as an
          // OUTLINE, and an outline only reads as "empty space" against a
          // surface. On the white page this used to sit on, an unfilled
          // rectangle read as a disabled control.
          //
          // It also ties the booking flow back to the dark map the user arrived
          // through, so the whole product reads as one surface.
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1626), Color(0xFF131020)],
              ),
              borderRadius: AppRadius.cardLarge,
              boxShadow: AppShadows.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Horizontally scrollable so a wide row stays reachable on a
                // narrow phone without the bays shrinking below a usable touch
                // target.
                // When a row is wider than the panel, the last bay is cut by
                // the panel edge — which reads as a rendering fault rather than
                // as "there is more this way". Fading the trailing edge makes
                // the overflow deliberate. Applied ONLY when it actually
                // overflows, so a plan that fits keeps hard, painted edges.
                _FadeTrailingEdge(
                  active: contentWidth > panelWidth,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: planWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < layout.rows.length; i++) ...[
                            _SlotRowView(
                              row: layout.rows[i],
                              selectedSlotId: selectedSlotId,
                              onSelect: onSelect,
                              vehicleType: layout.vehicleType,
                            ),
                            // An aisle between banks of bays, not after the last.
                            if (i < layout.rows.length - 1)
                              _Aisle(width: planWidth)
                            else
                              const SizedBox(height: AppSpacing.sm),
                          ],
                          // Inside the scrolled column, so its aisle shares the
                          // exact coordinate space as the aisles between rows.
                          // Outside it, the two were laid out against different
                          // widths and their centre markers did not line up.
                          _EntranceMarker(width: planWidth),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // The legend belongs ON the plan, where its swatches sit against
                // the same surface as the bays they describe.
                const _SlotLegendRow(),
              ],
            ),
          ),
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
    final available = summary.available;

    final (text, colour) = switch (available) {
      0 => ('No slots free for this time', AppColors.danger),
      1 => ('Only 1 slot left', AppColors.warning),
      _ when available <= 3 => ('Only $available slots left', AppColors.warning),
      _ => ('$available of ${summary.total} slots free', AppColors.success),
    };

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.text.bodyMedium?.copyWith(
              color: colour,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (summary.held > 0)
          Text(
            '${summary.held} being booked',
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// The legend.
///
/// Carries a shape as well as a colour for each state, because availability
/// communicated by colour alone is unreadable to a meaningful share of drivers.
/// What the bays mean.
///
/// Trimmed from five entries to four: "Unavailable" (a bay taken out of service)
/// is rare, and its crossed-circle glyph needs no explaining. Five swatches was
/// more legend than plan.
///
/// Swatches are built by the SAME function that draws the bays, so they cannot
/// disagree with what is on screen.
class _SlotLegendRow extends StatelessWidget {
  const _SlotLegendRow();

  @override
  Widget build(BuildContext context) {
    const entries = <(String, SlotStatus, bool)>[
      ('Free', SlotStatus.available, false),
      ('Yours', SlotStatus.available, true),
      ('Being booked', SlotStatus.held, false),
      ('Taken', SlotStatus.booked, false),
    ];

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: entries.map((entry) {
        final (label, status, selected) = entry;
        final look = _bayLook(status, selected: selected, heldByYou: false);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 20,
              decoration: BoxDecoration(
                color: look.fill,
                border: Border.all(color: look.line, width: 1.5),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                  bottom: Radius.circular(5),
                ),
              ),
              child:
                  Icon(look.icon ?? Icons.directions_car_rounded, size: 9, color: look.ink),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              label,
              style: context.text.bodySmall?.copyWith(color: AppColors.onMapMuted),
            ),
          ],
        );
      }).toList(growable: false),
    );
  }
}

class _SlotRowView extends StatelessWidget {
  const _SlotRowView({
    required this.row,
    required this.selectedSlotId,
    required this.onSelect,
    required this.vehicleType,
  });

  final SlotRow row;
  final int? selectedSlotId;
  final ValueChanged<ParkingSlot> onSelect;
  final VehicleType vehicleType;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 22,
          child: Text(
            row.label,
            style: AppTypography.slotCode(
              color: AppColors.onMapMuted,
              size: 14,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Row(
          children: row.slots
              .map((slot) => Padding(
                    padding: const EdgeInsets.only(right: _bayGap),
                    child: _SlotBay(
                      slot: slot,
                      isSelected: slot.id == selectedSlotId,
                      onTap: () => onSelect(slot),
                      vehicleType: vehicleType,
                    ),
                  ))
              .toList(growable: false),
        ),
      ],
    );
  }
}

/// One parking bay.
///
/// ─────────────────────────────────────────────────────────────────────────
/// A BAY, NOT A CELL
///
/// These were soft-tinted rounded rectangles on a white page — a data grid
/// that happened to be about parking. But this screen is the one genuinely
/// spatial moment in the product: the user is choosing a physical place they
/// will shortly drive into, and then has to FIND it on the ground.
///
/// So the layout is drawn as what it represents. The surface is tarmac, and the
/// bays are painted onto it: open lines for a free bay, a filled slab with a car
/// on it for a taken one. It reads as a floor plan at a glance, which is exactly
/// the mental model the user needs to carry into the car park.
///
/// ACCESSIBILITY: status is never carried by colour alone. Every state has a
/// distinct glyph AND a distinct fill treatment, and the whole bay is one
/// semantic button with a spoken label.
/// ─────────────────────────────────────────────────────────────────────────
class _SlotBay extends StatelessWidget {
  const _SlotBay({
    required this.slot,
    required this.isSelected,
    required this.onTap,
    required this.vehicleType,
  });

  final ParkingSlot slot;
  final bool isSelected;
  final VoidCallback onTap;

  /// What the layout is for, so a free bay can show the vehicle it takes.
  final VehicleType vehicleType;

  @override
  Widget build(BuildContext context) {
    final look = _appearance();

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: slot.isSelectable,
      label: 'Bay ${slot.code}, ${isSelected ? 'selected' : slot.status.label}'
          '${slot.slotClass.isSpecial ? ', ${slot.slotClass.label}' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // Selection pops: a brief overshoot past full size and back. A colour
        // change alone reads as a repaint rather than as a choice landing.
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: isSelected ? 1.09 : 1),
          duration: AppMotion.quick,
          curve: isSelected ? AppMotion.emphasised : AppMotion.standard,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: AnimatedContainer(
            duration: AppMotion.quick,
            curve: AppMotion.standard,
            width: AppSizes.slotTileWidth,
            height: AppSizes.slotTileHeight,
            decoration: BoxDecoration(
              color: look.fill,
              border: Border.all(color: look.line, width: isSelected ? 2.5 : 2),
              borderRadius: const BorderRadius.vertical(
                // Bays open toward the aisle: square at the kerb end, rounded
                // where a car drives in. A small thing that makes the plan read
                // as a plan.
                top: Radius.circular(4),
                bottom: Radius.circular(AppRadius.xs),
              ),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: Color(0x805B34E8),
                        blurRadius: 18,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : AppShadows.none,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  // A free bay shows what it TAKES; every other state shows
                  // what is wrong with it. `_bayLook` returns null for the
                  // available case precisely so the vehicle type fills it.
                  look.icon ??
                      (vehicleType == VehicleType.bike
                          ? Icons.two_wheeler_rounded
                          : Icons.directions_car_rounded),
                  size: AppSizes.iconSm,
                  color: look.ink,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  slot.code,
                  style: AppTypography.slotCode(color: look.ink, size: 12.5),
                ),
                if (slot.slotClass.isSpecial)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      _classIcon(slot.slotClass),
                      size: AppSizes.iconXs - 2,
                      color: look.ink.withValues(alpha: 0.85),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _BayLook _appearance() => _bayLook(
        slot.status,
        selected: isSelected,
        heldByYou: slot.heldByYou,
      );

  static IconData _classIcon(SlotClass slotClass) {
    switch (slotClass) {
      case SlotClass.accessible:
        return Icons.accessible_rounded;
      case SlotClass.ev:
        return Icons.ev_station_rounded;
      case SlotClass.compact:
        return Icons.compress_rounded;
      case SlotClass.valet:
        return Icons.front_hand_rounded;
      case SlotClass.standard:
        return Icons.circle;
    }
  }
}

/// The single definition of how a bay looks in each state.
///
/// Shared by the bays and by the legend, so the two cannot drift. They already
/// had: the legend was still drawing the old soft-tinted swatches after the bays
/// became painted outlines, which is exactly the failure a legend must not have.
_BayLook _bayLook(
  SlotStatus status, {
  required bool selected,
  required bool heldByYou,
}) {
  if (selected) {
    return const _BayLook(
      fill: AppColors.brand,
      line: AppColors.brandBright,
      ink: AppColors.onBrand,
      icon: Icons.check_rounded,
    );
  }

  switch (status) {
    case SlotStatus.available:
      // The vehicle glyph marks what the bay TAKES, not what is in it.
      //
      // An earlier pass drew free bays completely empty, reasoning that an
      // empty bay should look empty. That reads well in isolation and badly in
      // a row: a bay with a car outline and a bay with a motorcycle outline are
      // instantly distinguishable, and a lot with both car and bike sections is
      // otherwise a grid of identical rectangles told apart only by a letter.
      return const _BayLook(
        fill: Color(0x1F22C55E),
        line: AppColors.successBright,
        ink: AppColors.successBright,
        icon: null, // supplied per-slot from the layout's vehicle type
      );
    case SlotStatus.held:
      // A bay the caller holds reads as theirs, not as someone else's.
      return heldByYou
          ? const _BayLook(
              fill: Color(0x335B34E8),
              line: AppColors.brandMuted,
              ink: AppColors.brandMuted,
              icon: Icons.lock_clock_rounded,
            )
          : const _BayLook(
              fill: Color(0x1FE8A33D),
              line: Color(0xFFE8A33D),
              ink: Color(0xFFE8A33D),
              icon: Icons.hourglass_top_rounded,
            );
    case SlotStatus.booked:
      // Occupied: a car sitting in the bay. The most literal possible signal,
      // and the one that needs no legend.
      return const _BayLook(
        fill: Color(0xFF2A2536),
        line: Color(0xFF3A3448),
        ink: Color(0xFF8A829C),
        icon: Icons.directions_car_rounded,
      );
    case SlotStatus.closed:
      return const _BayLook(
        fill: Color(0xFF201C2A),
        line: Color(0xFF302A3C),
        ink: Color(0xFF6A6478),
        icon: Icons.block_rounded,
      );
  }
}

class _BayLook {
  const _BayLook({
    required this.fill,
    required this.line,
    required this.ink,
    this.icon,
  });

  final Color fill;
  final Color line;
  final Color ink;

  /// Null for a free bay, which is drawn empty on purpose.
  final IconData? icon;
}

/// The driving aisle between banks of bays.
///
/// Purely orienting, and that is the point: it is the difference between a grid
/// of codes and a picture of somewhere you can drive.
class _Aisle extends StatelessWidget {
  const _Aisle({required this.width});

  /// Explicit, because the plan lives inside a horizontally scrolling viewport.
  ///
  /// This originally used `Expanded`, which needs a bounded width — and inside a
  /// `SingleChildScrollView(scrollDirection: Axis.horizontal)` the cross axis is
  /// `BoxConstraints(unconstrained)`. The result was not a visual glitch but a
  /// hard layout failure: "RenderBox was not laid out", cascading through twenty
  /// parents into a sliver assertion, so the entire slot screen rendered blank.
  ///
  /// Found by running the screen, not by analysis — an unbounded-constraint bug
  /// is invisible to the analyser and only fires on the device.
  final double width;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            Expanded(
              child: CustomPaint(
                size: const Size(double.infinity, 2),
                painter: _DashedLinePainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Icon(
                Icons.swap_vert_rounded,
                size: AppSizes.iconXs,
                color: AppColors.onMapMuted.withValues(alpha: 0.7),
              ),
            ),
            Expanded(
              child: CustomPaint(
                size: const Size(double.infinity, 2),
                painter: _DashedLinePainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The painted centre line of the aisle.
class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.onMapMuted.withValues(alpha: 0.32)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dash = 10.0;
    const gap = 8.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dash).clamp(0, size.width), size.height / 2),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) => false;
}

/// Orients the layout. Drawn after the rows because the server orders rows A→Z
/// starting from the entrance.
class _EntranceMarker extends StatelessWidget {
  const _EntranceMarker({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Aisle(width: width),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs + 1,
              ),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.06),
                borderRadius: AppRadius.chip,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.login_rounded,
                      size: AppSizes.iconXs, color: AppColors.onMapMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'ENTRANCE',
                    style: AppTypography.overline(color: AppColors.onMapMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/* ── bottom bar ────────────────────────────────────────────────────────────── */

class _BottomBar extends StatelessWidget {
  const _BottomBar({
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
    final selected =
        draft.selectedSlotId == null ? null : layout?.findById(draft.selectedSlotId!);

    // A WHITE sheet on the dark floor plan.
    //
    // This is the product's light-surface rule doing real work rather than
    // decoration: the plan above is a dark spatial diagram you read, and this is
    // the bright surface you act on. The contrast is what makes the commitment
    // feel like a separate step from the browsing.
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.sheet,
        boxShadow: AppShadows.sheet,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selected == null ? 'No slot selected' : '${selected.code} selected',
                      style: context.text.headlineSmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selected == null
                          ? 'Tap an available slot'
                          // Row and class, which is what the customer will look
                          // for on the ground — not a note about pricing they
                          // are one tap away from seeing anyway.
                          // The row prefix comes off the code itself — "A1" is
                          // in row A. `ParkingSlot` carries no row field; the
                          // grouping lives on `SlotRow`, which this bar does
                          // not have a handle on.
                          : [
                              if (selected.code.isNotEmpty &&
                                  RegExp(r'^[A-Za-z]').hasMatch(selected.code))
                                'Row ${selected.code[0].toUpperCase()}',
                              // `label` is null for a standard slot — the model uses
                              // null to mean "nothing special about this one".
                              // Joining it straight in printed the literal "null".
                              selected.slotClass.label ?? 'Standard slot',
                            ].join(' · '),
                      style: context.text.bodySmall?.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              SizedBox(
                width: 150,
                child: PrimaryButton(
                  label: 'Continue',
                  isLoading: isHolding,
                  onPressed: selected == null ? null : onContinue,
                ),
              ),
            ],
          ),
        ),
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
        const LoadingSkeleton.text(width: 180),
        const SizedBox(height: AppSpacing.lg),
        const LoadingSkeleton(height: 20),
        const SizedBox(height: AppSpacing.xl),
        for (var row = 0; row < 4; row++) ...[
          Row(
            children: [
              const LoadingSkeleton.text(width: 16, height: 16),
              const SizedBox(width: AppSpacing.md),
              for (var i = 0; i < 4; i++) ...[
                const LoadingSkeleton(
                  width: AppSizes.slotTileWidth,
                  height: AppSizes.slotTileHeight,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}
