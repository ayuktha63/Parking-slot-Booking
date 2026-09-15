// ─────────────────────────────────────────────────────────────────────────────
// LOADING, ERROR AND EMPTY STATES
//
// Every async surface resolves through one of these, so nothing shows a blank
// page or a lone spinner. Skeletons take the shape of the content they stand in
// for; errors say what happened and offer the one thing that can fix it; empty
// states say what will appear here and how to make it appear.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'buttons.dart';

class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.borderRadius = AppRadius.tile,
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
    return Shimmer.fromColors(
      baseColor: AppColors.fill,
      highlightColor: AppColors.fillSubtle,
      period: const Duration(milliseconds: 1300),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(color: AppColors.fill, borderRadius: borderRadius),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final ApiException error;
  final VoidCallback? onRetry;
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
      tint: error.kind == ApiErrorKind.offline ? AppColors.ink : AppColors.negative,
      title: error.title,
      message: error.message,
      compact: compact,
      action: (onRetry != null && error.isRetryable)
          ? PillButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: onRetry)
          : null,
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _StateScaffold(
      icon: icon,
      tint: AppColors.ink,
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
    required this.tint,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final disc = compact ? 56.0 : 72.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: compact ? AppSpacing.xl : AppSpacing.huge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: disc,
              height: disc,
              decoration: const BoxDecoration(color: AppColors.fill, shape: BoxShape.circle),
              child: Icon(icon, size: disc * 0.44, color: tint),
            ),
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            Text(
              title,
              style: compact ? context.text.titleLarge : context.text.headlineMedium,
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
