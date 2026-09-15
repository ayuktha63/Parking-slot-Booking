// ─────────────────────────────────────────────────────────────────────────────
// CANCEL
//
// Shows the server's cancellation preview — exactly what comes back and what
// does not — before anything is cancelled. Nothing here computes a refund.
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
import '../../../shared/widgets/surfaces.dart';

Future<bool> showCancelBookingSheet(BuildContext context, WidgetRef ref, Booking booking) async {
  final result = await showAppSheet<bool>(
    context: context,
    child: _CancelBookingSheet(booking: booking),
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(title: 'Cancel booking?', subtitle: widget.booking.parking.name),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageInset,
                  0,
                  AppSpacing.pageInset,
                  AppSpacing.lg,
                ),
                child: preview.when(
                  loading: () => const Column(
                    children: [
                      SizedBox(height: AppSpacing.md),
                      LoadingSkeleton(height: 96, borderRadius: AppRadius.card),
                      SizedBox(height: AppSpacing.lg),
                      LoadingSkeleton(height: 56),
                    ],
                  ),
                  error: (error, _) => ErrorStateView(
                    error: asApiException(error),
                    compact: true,
                    onRetry: () => ref.invalidate(cancellationPreviewProvider(widget.booking.id)),
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
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            preview.wasPaid && preview.refund.paise > 0
                ? 'Booking cancelled. ${preview.refund.display} is on its way back to you.'
                : 'Booking cancelled.',
          ),
          duration: const Duration(seconds: 5),
        ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      showToast(context, e.message);
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
          const InlineBanner(
            message: 'This booking can no longer be cancelled.',
            tone: BannerTone.warning,
          ),
          const SizedBox(height: AppSpacing.lg),
          SecondaryButton(label: 'Close', onPressed: onKeep),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preview.wasPaid) ...[
          AppSurface(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Column(
              children: [
                InfoRow(label: 'You paid', value: booking.amount.reserved.display),
                InfoRow(
                  label: 'Refund (${preview.refundPercent}%)',
                  value: preview.refund.display,
                  valueColor: preview.refund.paise > 0 ? AppColors.positive : AppColors.ink,
                  emphasise: true,
                ),
                if (preview.retained.paise > 0)
                  InfoRow(label: 'Not refunded', value: preview.retained.display),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (preview.policy.isNotEmpty) Text(preview.policy, style: context.text.bodyMedium),
          if (preview.refund.paise > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Refunds usually reach your account in 5–7 working days.',
              style: context.text.bodySmall,
            ),
          ],
        ] else
          const InlineBanner(
            message: 'No payment was taken for this booking, so there is nothing to refund.',
          ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          label: 'Reason (optional)',
          controller: reason,
          hint: 'Plans changed',
          maxLength: 120,
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Cancel booking',
          tone: ButtonTone.danger,
          isLoading: isCancelling,
          onPressed: onConfirm,
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(child: TertiaryButton(label: 'Keep my booking', onPressed: isCancelling ? null : onKeep)),
      ],
    );
  }
}
