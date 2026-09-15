// ─────────────────────────────────────────────────────────────────────────────
// BOOKED — "You're all set."
//
// Reached only after the server confirms payment (a booking whose status is
// CONFIRMED or later). Everything shown is the server's: the place and its photo,
// the spot, the window, the booking code and the amount actually paid. The one
// thing the customer needs next is the code, so it is the largest thing here.
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
import '../../../shared/widgets/parqx_photo.dart';
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
            : SafeArea(child: _Body(booking: booking, animation: _controller, onClose: _done)),
        bottomNavigationBar: booking == null
            ? null
            : BottomActionBar(
                divider: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (booking.parking.position != null) ...[
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
                      SecondaryButton(
                        label: 'View booking',
                        onPressed: () => openBookingAfterFlow(context, booking.id),
                      ),
                    ] else
                      PrimaryButton(
                        label: 'View booking',
                        onPressed: () => openBookingAfterFlow(context, booking.id),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.booking, required this.animation, required this.onClose});

  final Booking booking;
  final Animation<double> animation;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final entry = booking.window.entryTime;
    final exit = booking.window.expectedExitTime;
    final now = DateTime.now();
    String? date;
    String? time;
    if (entry != null) {
      final isToday = entry.year == now.year && entry.month == now.month && entry.day == now.day;
      date = isToday
          ? 'Today, ${DateFormat('d MMM').format(entry)}'
          : DateFormat('EEE, d MMM').format(entry);
      time = '${DateFormat('h:mm a').format(entry)}'
          '${exit != null ? ' – ${DateFormat('h:mm a').format(exit)}' : ''}';
    }
    final place = booking.parking;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageInset,
        AppSpacing.sm,
        AppSpacing.pageInset,
        AppSpacing.xl,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: CircleButton(icon: Icons.close_rounded, tooltip: 'Close', onPressed: onClose),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SuccessMark(animation: animation),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: Text("You're all set.", style: context.text.displayMedium),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            ParqxPhoto(url: place.coverPhotoUrl, seed: place.name, width: 64, height: 64),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: context.text.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (place.addressLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      place.addressLabel!,
                      style: context.text.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // A compact grid rather than a row each: on a 360×800 phone, rows pushed
        // the booking code — the thing needed at the gate — below the fold.
        _DetailGrid(cells: [
          if (booking.slot != null) ('Spot', booking.slot!.code),
          if (date != null) ('Date', date),
          if (time != null) ('Time', time),
          ('Duration', booking.window.durationLabel),
        ]),
        const SizedBox(height: AppSpacing.lg),
        _EntryCode(code: booking.code),
        const SizedBox(height: AppSpacing.lg),
        InfoRow(
          label: booking.payment.isPaid ? 'Amount paid' : 'Amount',
          value: booking.amount.reserved.display,
          emphasise: true,
        ),
        if (booking.payment.reference != null)
          InfoRow(label: 'Payment reference', value: booking.payment.reference!),
        if (place.instructions != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineBanner(
            title: 'Getting in',
            message: place.instructions!,
            icon: Icons.directions_walk_rounded,
          ),
        ],
      ],
    );
  }
}

/// Label over value, two to a row.
class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.cells});

  final List<(String, String)> cells;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Column(
        children: [
          for (var i = 0; i < cells.length; i += 2) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, value) in cells.skip(i).take(2))
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: context.text.bodySmall),
                        const SizedBox(height: 2),
                        Text(value, style: context.text.titleMedium),
                      ],
                    ),
                  ),
                if (cells.length - i == 1) const Spacer(),
              ],
            ),
          ],
        ],
      ),
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
          Text('Booking code', style: context.text.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
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
          const SizedBox(height: AppSpacing.xs),
          Text('Show this code at the entrance', style: context.text.bodySmall),
        ],
      ),
    );
  }
}
