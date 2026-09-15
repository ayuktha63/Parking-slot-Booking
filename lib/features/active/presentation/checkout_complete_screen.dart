// ─────────────────────────────────────────────────────────────────────────────
// SESSION COMPLETE
//
// Shown after a real check-out. The amount is the server's final figure, the
// times are the recorded check-in and check-out — the end of the trip, stated
// plainly, with the receipt one tap away.
// ─────────────────────────────────────────────────────────────────────────────

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
import '../../../shared/models/booking.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/parqx_photo.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/surfaces.dart';

class CheckoutCompleteScreen extends ConsumerStatefulWidget {
  const CheckoutCompleteScreen({super.key, required this.bookingId, this.initial});

  final int bookingId;
  final Booking? initial;

  @override
  ConsumerState<CheckoutCompleteScreen> createState() => _CheckoutCompleteScreenState();
}

class _CheckoutCompleteScreenState extends ConsumerState<CheckoutCompleteScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.emphasis,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() => context.go(Routes.home);

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
                child: Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(label: 'Done', onPressed: _done),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        label: 'View receipt',
                        icon: Icons.receipt_long_outlined,
                        // From Activity, not on top of whatever led here: the
                        // session was often opened from this booking's page, and
                        // Back then showed the same booking a second time.
                        onPressed: () => openBookingAfterFlow(context, booking.id),
                      ),
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
    final amount = booking.amount;
    final total = amount.finalAmount ?? amount.reserved;
    final inAt = booking.checkedInAt;
    final outAt = booking.checkedOutAt;
    final overstay = amount.finalAmount != null && amount.finalAmount!.paise > amount.reserved.paise
        ? amount.finalAmount! - amount.reserved
        : null;

    String? span;
    if (inAt != null && outAt != null) {
      final minutes = outAt.difference(inAt).inMinutes;
      final length = minutes < 1
          ? 'under a minute'
          : minutes < 60
              ? '$minutes min'
              : '${minutes ~/ 60}h ${minutes % 60}m';
      span = '${DateFormat('h:mm a').format(inAt)} – ${DateFormat('h:mm a').format(outAt)}  ·  $length';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageInset, AppSpacing.xxxl, AppSpacing.pageInset, AppSpacing.xl),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: AppMotion.emphasised),
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 38, color: AppColors.white),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Thanks for parking', style: context.text.displayMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Your session has ended and the spot is free again.',
          style: context.text.bodyLarge?.copyWith(color: AppColors.inkSecondary),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppSurface(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total', style: context.text.bodyMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(total.display, style: AppTypography.numeric(size: 44, weight: FontWeight.w700)),
              if (span != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(span, style: context.text.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.lg),
              const Hairline(),
              const SizedBox(height: AppSpacing.sm),
              InfoRow(label: 'Booked amount', value: amount.reserved.display),
              if (overstay != null)
                InfoRow(label: 'Overstay', value: overstay.display, valueColor: AppColors.warning),
              if (amount.hasRefund)
                InfoRow(label: 'Refunded', value: amount.refunded.display, valueColor: AppColors.positive),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      booking.payment.isPaid ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                      size: 16,
                      color: booking.payment.isPaid ? AppColors.positive : AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Text(
                      booking.payment.isPaid ? 'Paid' : 'Payment not completed',
                      style: context.text.bodyMedium?.copyWith(
                        color: booking.payment.isPaid ? AppColors.positive : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            ParqxPhoto(url: booking.parking.coverPhotoUrl, seed: booking.parking.name, width: 56, height: 56),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking.parking.name, style: context.text.titleMedium),
                  Text(
                    [
                      if (booking.slot != null) 'Spot ${booking.slot!.code}',
                      if (booking.vehicle.displayPlate != null) booking.vehicle.displayPlate!,
                    ].join('  ·  '),
                    style: context.text.bodyMedium,
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
