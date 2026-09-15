// ─────────────────────────────────────────────────────────────────────────────
// BOOKED
//
// Reached only after the server confirms payment. The one thing the customer
// needs next is the entry code, so it is the largest thing on the screen.
//
// Rebuilds from the booking id alone: the booking object passed by the review
// screen is just a head start while the fresh copy loads.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/booking_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/directions.dart';
import '../../../core/utils/haptics.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/surfaces.dart';

class BookingConfirmationScreen extends ConsumerStatefulWidget {
  const BookingConfirmationScreen({super.key, required this.bookingId, this.initial});

  final int bookingId;
  final Booking? initial;

  @override
  ConsumerState<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends ConsumerState<BookingConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.emphasis,
  )..forward();

  @override
  void initState() {
    super.initState();
    Haptics.success();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() => context.go(Routes.bookings);

  @override
  Widget build(BuildContext context) {
    final fresh = ref.watch(bookingDetailProvider(widget.bookingId));
    final booking = fresh.valueOrNull ?? widget.initial;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: booking == null
            ? (fresh.hasError
                ? ErrorStateView(
                    error: asApiException(fresh.error),
                    onRetry: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
                  )
                : const Center(child: CircularProgressIndicator()))
            : SafeArea(child: _Body(booking: booking, animation: _controller)),
        bottomNavigationBar: booking == null
            ? null
            : BottomActionBar(
                divider: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (booking.parking.position != null)
                      PrimaryButton(
                        label: 'Get directions',
                        icon: Icons.near_me_rounded,
                        onPressed: () => openDirectionsTo(
                          context,
                          booking.parking.position!,
                          booking.parking.name,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'View booking',
                            onPressed: () => openBookingAfterFlow(context, booking.id),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: SecondaryButton(label: 'Done', onPressed: _done)),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.booking, required this.animation});

  final Booking booking;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final entry = booking.window.entryTime;
    final exit = booking.window.expectedExitTime;
    final now = DateTime.now();
    String? when;
    if (entry != null) {
      final isToday = entry.year == now.year && entry.month == now.month && entry.day == now.day;
      final day = isToday ? 'Today' : DateFormat('EEE d MMM').format(entry);
      when = '$day, ${DateFormat('h:mm a').format(entry)}'
          '${exit != null ? ' – ${DateFormat('h:mm a').format(exit)}' : ''}';
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageInset,
            AppSpacing.xxxl,
            AppSpacing.pageInset,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SuccessMark(animation: animation),
              const SizedBox(height: AppSpacing.xl),
              Semantics(
                header: true,
                child: Text("You're booked", style: context.text.displayMedium),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [booking.parking.name, if (booking.slot != null) 'Spot ${booking.slot!.code}']
                    .join(' · '),
                style: context.text.bodyLarge?.copyWith(color: AppColors.inkSecondary),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _EntryCode(code: booking.code),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (when != null) ListRow(icon: Icons.schedule_rounded, title: when, subtitle: booking.window.durationLabel),
        if (booking.vehicle.displayPlate != null)
          ListRow(
            icon: booking.vehicle.type.wire == 'bike'
                ? Icons.two_wheeler_rounded
                : Icons.directions_car_filled_rounded,
            title: booking.vehicle.displayPlate!,
            subtitle: booking.vehicle.type.label,
          ),
        if (booking.parking.addressLabel != null)
          ListRow(icon: Icons.place_outlined, title: booking.parking.addressLabel!),
        ListRow(
          icon: booking.payment.isPaid ? Icons.check_rounded : Icons.hourglass_top_rounded,
          title: booking.payment.isPaid
              ? 'Paid ${booking.amount.reserved.display}'
              : 'Payment is still being confirmed',
          subtitle: booking.payment.reference,
        ),
        if (booking.parking.instructions != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
            child: InlineBanner(
              title: 'Getting in',
              message: booking.parking.instructions!,
              icon: Icons.directions_walk_rounded,
            ),
          ),
        ],
      ],
    );
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: AppMotion.emphasised),
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(color: AppColors.positiveBright, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 38, color: AppColors.white),
      ),
    );
  }
}

class _EntryCode extends StatelessWidget {
  const _EntryCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      level: SurfaceLevel.outlined,
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Show this code at the entrance', style: context.text.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  // Plain text: Copy covers copying, and a SelectableText is a read-only
                  // text field to TalkBack, which folded this whole card — heading and
                  // Copy button included — into one node that read only the code.
                  child: Text(code, style: AppTypography.code(size: 34, spacing: 2.5)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              PillButton(
                label: 'Copy',
                icon: Icons.copy_rounded,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) showToast(context, 'Booking code copied');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
