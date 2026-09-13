// ─────────────────────────────────────────────────────────────────────────────
// CONFIRMED
//
// The trust moment. Everything on this screen is a field from the confirmed
// booking the server returned.
//
// What is deliberately NOT here: a QR code. PARQX's access credential is the
// booking code, which the operator searches for or the driver reads out — a flow
// that works end to end today. A QR would imply a scanner at the barrier that does
// not exist, which is precisely the kind of UI this rewrite exists to remove.
//
// The old success screen showed `1000 + Random().nextInt(9000)` as the reference —
// a different number on every rebuild, matching nothing — and "$5.00" as the amount.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';

class BookingConfirmationScreen extends ConsumerStatefulWidget {
  const BookingConfirmationScreen({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
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
    // The booking is confirmed and paid. This is the single biggest commitment in
    // the product and the one moment that has genuinely earned a haptic — it lands
    // with the success mark's scale-in, not before it.
    Haptics.success();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    return PopScope(
      // Back must not return to the review screen of a booking already paid for.
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
        backgroundColor: context.colors.surface,
        body: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
            children: [
              // ── the one moment the product celebrates ──────────────────
              //
              // This screen was a white page with a green tick: correct,
              // complete, and instantly forgettable. It is the emotional peak of
              // the entire product — the point where money has changed hands and
              // a promise has been made — and it looked like a form had
              // validated.
              //
              // Deep violet, the brand at full strength, used on exactly one
              // screen. That scarcity is what makes it land: nothing else in the
              // app looks like this, so arriving here feels like arriving
              // somewhere.
              _CelebrationHero(
                animation: _controller,
                parkingName: booking.parking.name,
                code: booking.code,
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageInset,
                  // Clears the ticket hanging out of the hero above.
                  AppSpacing.huge + AppSpacing.xl,
                  AppSpacing.pageInset,
                  0,
                ),
                child: Column(children: [
              _DetailsCard(booking: booking),

              const SizedBox(height: AppSpacing.lg),
              _PaymentCard(booking: booking),

              if (booking.parking.instructions != null) ...[
                const SizedBox(height: AppSpacing.lg),
                InlineBanner(
                  message: booking.parking.instructions!,
                  icon: Icons.tips_and_updates_outlined,
                  tone: BannerTone.info,
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),

              if (booking.parking.hasCoordinates)
                PrimaryButton(
                  label: 'Get directions',
                  icon: Icons.navigation_rounded,
                  onPressed: _openDirections,
                ),

              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: 'View booking',
                onPressed: () => context.pushReplacement(Routes.bookingDetail(booking.id)),
              ),

              const SizedBox(height: AppSpacing.md),
              TertiaryButton(label: 'Done', onPressed: _done),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _done() => context.go(Routes.bookings);

  Future<void> _openDirections() async {
    final position = widget.booking.parking.position;
    if (position == null) return;

    // The platform's own maps handler. No API key, no embedded navigation to
    // maintain, and it opens whichever app the driver actually uses.
    final uri = Uri.parse(
      'geo:${position.latitude},${position.longitude}'
      '?q=${position.latitude},${position.longitude}'
      '(${Uri.encodeComponent(widget.booking.parking.name)})',
    );

    final fallback = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${position.latitude},${position.longitude}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(fallback)) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('No maps app is available on this device.')));
    }
  }
}

/// The celebration: deep violet, the success mark, and the access credential
/// presented as a ticket stub.
///
/// The credential deliberately overlaps the boundary between the hero and the
/// page. That overlap is what makes it read as a physical object handed to the
/// user rather than another section of a scrolling form — and the booking code
/// IS the thing they need at the barrier, so it should be the most object-like
/// element on the screen.
class _CelebrationHero extends StatelessWidget {
  const _CelebrationHero({
    required this.animation,
    required this.parkingName,
    required this.code,
  });

  final Animation<double> animation;
  final String parkingName;
  final String code;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageInset,
            topInset + AppSpacing.xxxl,
            AppSpacing.pageInset,
            // Room for the ticket, which hangs below the hero's edge.
            AppSpacing.giant + AppSpacing.xl,
          ),
          decoration: const BoxDecoration(
            gradient: AppGradients.celebration,
            borderRadius: BorderRadius.vertical(bottom: AppRadius.rXxl),
          ),
          child: Column(
            children: [
              _SuccessMark(animation: animation),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Your parking is booked',
                textAlign: TextAlign.center,
                style: context.text.displaySmall?.copyWith(color: AppColors.onMap),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                parkingName,
                textAlign: TextAlign.center,
                style: context.text.bodyLarge?.copyWith(color: AppColors.brandMuted),
              ),
            ],
          ),
        ),

        Positioned(
          left: AppSpacing.pageInset,
          right: AppSpacing.pageInset,
          bottom: -AppSpacing.huge,
          child: _AccessCredential(code: code, animation: animation),
        ),

        // Reserves the height the overhanging ticket occupies, so the content
        // below it starts in the right place instead of being overlapped.
        const Positioned.fill(child: IgnorePointer(child: SizedBox.shrink())),
      ],
    );
  }
}

/// A check mark that draws itself once. Emphasis where emphasis is earned.
class _SuccessMark extends StatelessWidget {
  const _SuccessMark({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(parent: animation, curve: AppMotion.emphasised);
    // The ring expands outward behind the mark and fades — one pulse, not a loop.
    final ring = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.25, 1, curve: Curves.easeOutCubic),
    );

    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: ring,
            builder: (context, _) => Container(
              width: 88 + 32 * ring.value,
              height: 88 + 32 * ring.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.successBright
                      .withValues(alpha: 0.45 * (1 - ring.value)),
                  width: 2,
                ),
              ),
            ),
          ),
          ScaleTransition(
            scale: scale,
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.successBright,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x6600C389),
                    blurRadius: 28,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, size: 48, color: Color(0xFF04301F)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The booking code, large, copyable, and labelled with what to do with it.
///
/// Deliberately NOT a QR code. PARQX's access credential is this code, which the
/// operator looks up or the driver reads out — a flow that works end to end
/// today. A QR would imply a scanner at the barrier that does not exist.
class _AccessCredential extends StatelessWidget {
  const _AccessCredential({required this.code, required this.animation});

  final String code;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0.3, 1, curve: AppMotion.spring),
        ),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.3, 0.8),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardLarge,
            boxShadow: AppShadows.lg,
          ),
          child: Column(
            children: [
              Text(
                'SHOW THIS AT THE ENTRANCE',
                style: AppTypography.overline(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              SelectableText(
                code,
                style: AppTypography.slotCode(color: AppColors.ink, size: 30)
                    .copyWith(letterSpacing: 3),
              ),
              const SizedBox(height: AppSpacing.sm),
              TertiaryButton(
                label: 'Copy code',
                icon: Icons.copy_rounded,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(
                      content: Text('Booking code copied'),
                      duration: Duration(seconds: 2),
                    ));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final entry = booking.window.entryTime;
    final exit = booking.window.expectedExitTime;

    return AppCard(
      child: Column(
        children: [
          if (entry != null)
            DetailRow(
              label: 'Arriving',
              value: DateFormat('EEE d MMM, h:mm a').format(entry),
              icon: Icons.login_rounded,
            ),
          if (exit != null)
            DetailRow(
              label: 'Leaving',
              value: entry != null && entry.day == exit.day
                  ? DateFormat('h:mm a').format(exit)
                  : DateFormat('EEE d MMM, h:mm a').format(exit),
              icon: Icons.logout_rounded,
            ),
          if (booking.slot != null)
            DetailRow(
              label: 'Slot',
              value: booking.slot!.code,
              icon: Icons.grid_view_rounded,
              emphasise: true,
            ),
          if (booking.vehicle.numberPlate != null)
            DetailRow(
              label: 'Vehicle',
              value: booking.vehicle.numberPlate!,
              icon: booking.vehicle.type.wire == 'bike'
                  ? Icons.two_wheeler_rounded
                  : Icons.directions_car_rounded,
            ),
          if (booking.parking.addressLabel != null)
            DetailRow(
              label: 'Address',
              value: booking.parking.addressLabel!,
              icon: Icons.location_on_outlined,
            ),
        ],
      ),
    );
  }
}

/// Payment, stated as the server reports it.
///
/// The reference is the provider's own, shown when there is one and omitted when
/// there is not. Nothing here claims an email or SMS was sent, because nothing in
/// the system sends one.
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          DetailRow(
            label: 'Amount paid',
            value: booking.amount.reserved.display,
            icon: Icons.receipt_long_outlined,
            emphasise: true,
          ),
          Row(
            children: [
              Icon(
                booking.payment.isPaid
                    ? Icons.verified_rounded
                    : Icons.hourglass_top_rounded,
                size: AppSizes.iconSm,
                color: booking.payment.isPaid ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  booking.payment.isPaid
                      ? 'Payment confirmed'
                      : 'Payment is still being confirmed',
                  style: context.text.bodySmall?.copyWith(
                    color: booking.payment.isPaid ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (booking.payment.reference != null) ...[
            const SizedBox(height: AppSpacing.sm),
            DetailRow(label: 'Reference', value: booking.payment.reference!),
          ],
        ],
      ),
    );
  }
}
