// ─────────────────────────────────────────────────────────────────────────────
// CHECK-OUT FLOW
//
// One way to end a session, wherever it starts: a confirmation sheet with the
// live duration and the server's running estimate, then the real check-out call,
// then the completion screen with the server's final amount.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/booking_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/live_duration.dart';

/// Returns true when the session was ended.
Future<bool> confirmAndCheckOut(
  BuildContext context,
  WidgetRef ref,
  Booking booking, {
  ValueChanged<bool>? onBusy,
}) async {
  final confirmed = await showAppSheet<bool>(
    context: context,
    child: _ConfirmSheet(booking: booking),
  );
  if (confirmed != true || !context.mounted) return false;

  onBusy?.call(true);
  try {
    final completed = await ref.read(bookingActionsProvider).checkOut(booking.id);
    if (!context.mounted) return true;
    Haptics.success();
    context.pushReplacement(Routes.checkoutComplete(completed.id), extra: completed);
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message);
    return false;
  } on Object catch (e) {
    if (context.mounted) showToast(context, asApiException(e).message);
    return false;
  } finally {
    onBusy?.call(false);
  }
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final since = booking.checkedInAt;
    final estimate = booking.session?.projectedTotal;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: 'End parking?', subtitle: booking.parking.name),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.pageInset, 0, AppSpacing.pageInset, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (since != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Parked for',
                            style: context.text.bodyLarge?.copyWith(color: AppColors.inkSecondary),
                          ),
                        ),
                        LiveDuration(
                          since: since,
                          alwaysHours: true,
                          style: AppTypography.numeric(size: 18, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                if (estimate != null)
                  InfoRow(label: 'Estimated so far', value: estimate.display, emphasise: true),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your final amount is worked out when you check out, from how long you actually '
                  'stayed. Make sure your vehicle has left the spot.',
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Check out',
                  icon: Icons.logout_rounded,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: TertiaryButton(
                    label: 'Keep parking',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
