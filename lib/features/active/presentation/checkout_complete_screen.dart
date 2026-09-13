// ─────────────────────────────────────────────────────────────────────────────
// CHECK-OUT COMPLETE — the end of the journey
//
// The counterpart to the booking confirmation, and the last thing a customer
// sees before a session becomes history.
//
// Check-out used to drop straight onto the booking detail screen. That screen
// is a RECORD — the same one they would open looking up a booking from six
// weeks ago — and arriving on it directly gave the end of the journey no shape
// at all: the timer simply stopped and a different screen appeared.
//
// ─────────────────────────────────────────────────────────────────────────────
// WHAT IT SHOWS, AND WHY EACH PART
//
//   the final amount   the single number the customer cares about, and the one
//                      they will check against their bank. It is the SERVER's
//                      `final_amount`, which exists only after check-out — this
//                      screen is the first place in the product that can show a
//                      settled figure rather than an estimate.
//   the span           in → out, so "why is it that much" is answerable without
//                      opening anything.
//   the place          with its photograph, closing the loop on the card they
//                      chose it from.
//
// It is deliberately calmer than the booking confirmation. Confirmation is a
// promise being made and gets the full violet celebration; this is a promise
// being kept, and quiet completion is the right register for it.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/parqx_photo.dart';
import '../../../shared/widgets/surfaces.dart';

class CheckoutCompleteScreen extends ConsumerStatefulWidget {
  const CheckoutCompleteScreen({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<CheckoutCompleteScreen> createState() =>
      _CheckoutCompleteScreenState();
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

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final amount = booking.amount.finalAmount ?? booking.amount.reserved;
    final inAt = booking.checkedInAt;
    final outAt = booking.checkedOutAt;

    return PopScope(
      // Back must not return to a live session that has ended.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: AppColors.canvas,
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pageInset,
              MediaQuery.paddingOf(context).top + AppSpacing.giant,
              AppSpacing.pageInset,
              AppSpacing.xxxl,
            ),
            children: [
              _Mark(animation: _controller),
              const SizedBox(height: AppSpacing.xl),

              Text(
                "You're all set",
                textAlign: TextAlign.center,
                style: context.text.displaySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Parking completed',
                textAlign: TextAlign.center,
                style: context.text.bodyLarge
                    ?.copyWith(color: AppColors.inkSecondaryDark),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // ── the number ──────────────────────────────────────────────
              AppSurface(
                color: AppColors.surfaceDark,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Text(
                      'FINAL AMOUNT',
                      style: AppTypography.overline(color: AppColors.inkMutedDark),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      amount.display,
                      style: AppTypography.priceHero(color: AppColors.inkDark),
                    ),
                    if (booking.amount.finalAmount == null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      // Only when the server has not settled a final figure.
                      Text(
                        'Amount reserved — the final figure follows shortly',
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall
                            ?.copyWith(color: AppColors.inkMutedDark),
                      ),
                    ],
                    if (inAt != null && outAt != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const Divider(height: 1, color: AppColors.borderDark),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('h:mm a').format(inAt.toLocal()),
                            style: AppTypography.numeric(
                              size: 15,
                              weight: FontWeight.w700,
                              color: AppColors.inkDark,
                            ),
                          ),
                          const Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: AppSpacing.md),
                            child: Icon(Icons.arrow_forward_rounded,
                                size: AppSizes.iconSm,
                                color: AppColors.inkMutedDark),
                          ),
                          Text(
                            DateFormat('h:mm a').format(outAt.toLocal()),
                            style: AppTypography.numeric(
                              size: 15,
                              weight: FontWeight.w700,
                              color: AppColors.inkDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── the place ───────────────────────────────────────────────
              AppSurface(
                color: AppColors.surfaceDark,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    ParqxPhoto(
                      url: booking.parking.coverPhotoUrl,
                      seed: booking.parking.name,
                      width: 52,
                      height: 52,
                      borderRadius: AppRadius.tile,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            booking.parking.name,
                            style: context.text.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Slot ${booking.slot?.code ?? '—'}'
                            '${booking.vehicle.numberPlate == null ? '' : ' · ${booking.vehicle.numberPlate}'}',
                            style: context.text.bodySmall
                                ?.copyWith(color: AppColors.inkMutedDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              PrimaryButton(
                label: 'View receipt',
                icon: Icons.receipt_long_outlined,
                onPressed: () =>
                    context.pushReplacement(Routes.bookingDetail(booking.id)),
              ),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: 'Find parking',
                icon: Icons.search_rounded,
                onPressed: _done,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _done() => context.go(Routes.home);
}

/// A completion mark. Calmer than the booking confirmation's — one ring, one
/// tick, no burst.
class _Mark extends StatelessWidget {
  const _Mark({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: AppMotion.emphasised),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.35),
                blurRadius: 26,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.check_rounded, size: 46, color: AppColors.white),
        ),
      ),
    );
  }
}
