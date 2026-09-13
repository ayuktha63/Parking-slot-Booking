// ─────────────────────────────────────────────────────────────────────────────
// CANCEL
//
// The customer is told exactly what they get back BEFORE they confirm.
//
// The figure comes from /bookings/:id/cancellation-preview, which applies the same
// refund slabs the cancellation itself will. The old flow showed "Booking
// Cancelled" and never mentioned money at any point — and deleted the row, so there
// was nothing to look back at either.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/booking_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';

/// Shows the sheet. Returns true when the booking was cancelled.
Future<bool> showCancelBookingSheet(
  BuildContext context,
  WidgetRef ref,
  Booking booking,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CancelBookingSheet(booking: booking),
  );
  return result ?? false;
}

class _CancelBookingSheet extends ConsumerStatefulWidget {
  const _CancelBookingSheet({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_CancelBookingSheet> createState() => _CancelBookingSheetState();
}

class _CancelBookingSheetState extends ConsumerState<_CancelBookingSheet> {
  final TextEditingController _reason = TextEditingController();
  bool _isCancelling = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(cancellationPreviewProvider(widget.booking.id));

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.sheet,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHeader(title: 'Cancel this booking?'),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageInset,
                  0,
                  AppSpacing.pageInset,
                  AppSpacing.lg,
                ),
                child: preview.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Column(
                      children: [
                        LoadingSkeleton(height: 80),
                        SizedBox(height: AppSpacing.lg),
                        LoadingSkeleton(height: 52),
                      ],
                    ),
                  ),
                  error: (error, _) => ErrorStateView(
                    error: asApiException(error),
                    compact: true,
                    onRetry: () =>
                        ref.invalidate(cancellationPreviewProvider(widget.booking.id)),
                  ),
                  data: (data) => _Body(
                    preview: data,
                    booking: widget.booking,
                    reason: _reason,
                    isCancelling: _isCancelling,
                    onConfirm: () => _cancel(data),
                    onKeep: () => Navigator.of(context).pop(false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancel(CancellationPreview preview) async {
    setState(() => _isCancelling = true);

    try {
      await ref.read(bookingActionsProvider).cancel(
            widget.booking.id,
            reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            // Only mentions a refund when there genuinely is one.
            preview.wasPaid && preview.refund.paise > 0
                ? 'Booking cancelled. ${preview.refund.display} will be refunded to your '
                    'original payment method.'
                : 'Booking cancelled.',
          ),
          duration: const Duration(seconds: 5),
        ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.preview,
    required this.booking,
    required this.reason,
    required this.isCancelling,
    required this.onConfirm,
    required this.onKeep,
  });

  final CancellationPreview preview;
  final Booking booking;
  final TextEditingController reason;
  final bool isCancelling;
  final VoidCallback onConfirm;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    if (!preview.isCancellable) {
      return Column(
        children: [
          InlineBanner(
            message: 'This booking can no longer be cancelled.',
            tone: BannerTone.warning,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(label: 'Close', onPressed: onKeep),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          booking.parking.name,
          style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.lg),

        // The money, stated plainly. Shown only when money actually changed hands.
        if (preview.wasPaid) ...[
          AppCard(
            child: Column(
              children: [
                DetailRow(label: 'You paid', value: booking.amount.reserved.display),
                DetailRow(
                  label: 'Refund (${preview.refundPercent}%)',
                  value: preview.refund.display,
                  emphasise: true,
                  valueColor:
                      preview.refund.paise > 0 ? AppColors.success : AppColors.inkMuted,
                ),
                if (preview.retained.paise > 0)
                  DetailRow(label: 'Not refunded', value: preview.retained.display),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            // The policy sentence comes from the server, so the app never
            // paraphrases a rule it does not own.
            preview.policy,
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          if (preview.refund.paise > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Refunds usually reach your account within 5–7 working days.',
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ] else
          InlineBanner(
            message: 'No payment has been taken for this booking, so there is nothing '
                'to refund.',
            tone: BannerTone.info,
          ),

        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Reason (optional)',
          controller: reason,
          hint: 'Plans changed',
          maxLength: 120,
        ),

        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Cancel booking',
          danger: true,
          isLoading: isCancelling,
          onPressed: onConfirm,
        ),
        const SizedBox(height: AppSpacing.sm),
        TertiaryButton(label: 'Keep my booking', onPressed: isCancelling ? null : onKeep),
      ],
    );
  }
}
