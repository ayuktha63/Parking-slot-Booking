// ─────────────────────────────────────────────────────────────────────────────
// LOADING / ERROR / EMPTY STATES
//
// Every list and every screen uses these. Not optional.
//
// The old app had none: `catch (_) { parkingPlaces = []; }` meant a network failure
// and "no parking nearby" rendered identically — an empty area under a heading, with
// no message and no way to retry.
//
// Each state answers two questions: what happened, and what can I do about it.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'buttons.dart';
import 'parqx_illustration.dart';

/// Shimmering placeholder shaped like the content that is coming.
///
/// A skeleton in the shape of the result reads as "loading"; a centred spinner over
/// a blank page reads as "broken".
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.borderRadius = AppRadius.card,
  });

  const LoadingSkeleton.text({super.key, this.width = 120, this.height = 14})
      : borderRadius = const BorderRadius.all(Radius.circular(AppRadius.xs));

  const LoadingSkeleton.circle({super.key, double size = 40})
      : height = size,
        width = size,
        borderRadius = const BorderRadius.all(Radius.circular(999));

  final double height;
  final double width;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final base = context.isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt;
    final highlight = context.isDark ? AppColors.borderDark : AppColors.border;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1400),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(color: base, borderRadius: borderRadius),
      ),
    );
  }
}

/// Something went wrong, with the one action that might fix it.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final ApiException error;
  final VoidCallback? onRetry;

  /// For errors inside a section rather than a whole screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = switch (error.kind) {
      ApiErrorKind.offline => Icons.wifi_off_rounded,
      ApiErrorKind.timeout => Icons.hourglass_empty_rounded,
      ApiErrorKind.notFound => Icons.search_off_rounded,
      ApiErrorKind.forbidden => Icons.lock_outline_rounded,
      ApiErrorKind.notImplemented => Icons.construction_rounded,
      _ => Icons.error_outline_rounded,
    };

    return _StateScaffold(
      icon: icon,
      iconColour: error.kind == ApiErrorKind.offline ? AppColors.inkMuted : AppColors.danger,
      title: error.title,
      message: error.message,
      compact: compact,
      // Only offer a retry when retrying could actually help. A 403 does not get a
      // "Try again" button that will fail identically.
      action: (onRetry != null && error.isRetryable)
          ? SecondaryButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              expand: false,
              onPressed: onRetry,
              size: AppButtonSize.compact,
            )
          : null,
    );
  }
}

/// Nothing to show — and that is a normal outcome, not a failure.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.compact = false,
    this.illustrated = true,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  final bool compact;

  /// Draws the painted illustration instead of a plain tinted disc.
  ///
  /// On by default for full-page states, which is where a user has landed
  /// expecting content and found none — that moment deserves something
  /// composed. Compact in-section states keep the disc: an illustration inside
  /// a half-height sheet is a decoration competing with the content around it.
  final bool illustrated;

  @override
  Widget build(BuildContext context) {
    return _StateScaffold(
      icon: icon,
      illustrated: illustrated && !compact,
      // `outline` (#E9E6F1) on a white surface is roughly 1.05:1 — the glyph was
      // there in the widget tree and invisible on the screen, which made every
      // empty state look like a layout bug. `inkSubtle` is 3.66:1, which clears
      // the 3:1 that non-text graphics require while staying clearly quieter
      // than the title beneath it.
      iconColour: AppColors.inkSubtle,
      title: title,
      message: message,
      action: action,
      compact: compact,
    );
  }
}

class _StateScaffold extends StatelessWidget {
  const _StateScaffold({
    required this.icon,
    required this.iconColour,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
    this.illustrated = false,
  });

  final IconData icon;
  final Color iconColour;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;
  final bool illustrated;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: compact ? AppSpacing.xl : AppSpacing.huge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustrated)
              ParqxIllustration(icon: icon, onDark: context.isDark)
            else
              Container(
                width: compact ? 56 : 72,
                height: compact ? 56 : 72,
                decoration: BoxDecoration(
                  color: iconColour.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: compact ? 26 : 34, color: iconColour),
              ),
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            Text(
              title,
              style: compact ? context.text.titleMedium : context.text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: context.text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders an AsyncValue with all three states handled, so a screen cannot
/// accidentally omit one.
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.value,
    required this.data,
    required this.loading,
    this.onRetry,
    this.errorCompact = false,
  });

  /// `AsyncValue<T>` from Riverpod, passed loosely to avoid a hard dependency here.
  final AsyncSnapshotLike<T> value;
  final Widget Function(T data) data;
  final Widget Function() loading;
  final VoidCallback? onRetry;
  final bool errorCompact;

  @override
  Widget build(BuildContext context) {
    if (value.isLoading && !value.hasValue) return loading();

    final error = value.error;
    if (error != null && !value.hasValue) {
      final apiError = error is ApiException ? error : ApiException.unknown(error);
      return ErrorStateView(error: apiError, onRetry: onRetry, compact: errorCompact);
    }

    final v = value.valueOrNull;
    if (v == null) return loading();
    return data(v);
  }
}

/// Minimal shape of Riverpod's AsyncValue, so this widget file does not import
/// Riverpod and can be reused in widget tests without a container.
class AsyncSnapshotLike<T> {
  const AsyncSnapshotLike({
    required this.isLoading,
    required this.hasValue,
    this.valueOrNull,
    this.error,
  });

  final bool isLoading;
  final bool hasValue;
  final T? valueOrNull;
  final Object? error;
}
