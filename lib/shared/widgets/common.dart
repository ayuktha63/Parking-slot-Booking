// ─────────────────────────────────────────────────────────────────────────────
// COMMON BUILDING BLOCKS
//
// Rows, not cards. A mobility app reads as a list of clear statements — an icon
// in a grey disc, a bold line, a grey line, a value — separated by hairlines.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'buttons.dart';
import 'interaction.dart';
import 'surfaces.dart';

/// A section title with an optional text action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.pageInset,
            AppSpacing.xxl,
            AppSpacing.pageInset,
            AppSpacing.sm,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: context.text.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.text.bodyMedium),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            Pressable(
              onTap: onAction,
              depth: PressDepth.firm,
              tint: false,
              borderRadius: AppRadius.chip,
              semanticLabel: actionLabel,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  actionLabel!,
                  style: context.text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A grey disc holding an icon — the leading element of a row.
class IconDisc extends StatelessWidget {
  const IconDisc({
    super.key,
    required this.icon,
    this.size = AppSizes.iconDisc,
    this.color = AppColors.fill,
    this.iconColor = AppColors.ink,
  });

  final IconData icon;
  final double size;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.5, color: iconColor),
    );
  }
}

/// The standard list row: leading, a bold line, a grey line, and a trailing
/// value or chevron.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.icon,
    this.trailing,
    this.value,
    this.onTap,
    this.chevron,
    this.destructive = false,
    this.padding,
    this.dense = false,
  });

  final String title;
  final String? subtitle;

  /// A custom leading widget. [icon] is a shorthand for a grey [IconDisc].
  final Widget? leading;
  final IconData? icon;

  final Widget? trailing;

  /// A short grey value shown on the right, before the chevron.
  final String? value;

  final VoidCallback? onTap;

  /// Defaults to showing a chevron whenever the row is tappable.
  final bool? chevron;

  final bool destructive;
  final EdgeInsetsGeometry? padding;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final lead = leading ?? (icon == null ? null : IconDisc(icon: icon!, size: dense ? 36 : 40));
    final showChevron = chevron ?? onTap != null;
    final titleStyle = context.text.titleMedium?.copyWith(
      color: destructive ? AppColors.negative : AppColors.ink,
      fontWeight: subtitle == null ? FontWeight.w500 : FontWeight.w600,
    );

    final row = Padding(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: AppSpacing.pageInset,
            vertical: dense ? AppSpacing.md : AppSpacing.md + 2,
          ),
      child: Row(
        children: [
          if (lead != null) ...[lead, const SizedBox(width: AppSpacing.lg)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: context.text.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                value!,
                style: context.text.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: AppSpacing.md), trailing!],
          if (showChevron) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right_rounded,
                size: AppSizes.iconMd, color: AppColors.inkDisabled),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return Pressable(
      onTap: onTap,
      depth: PressDepth.subtle,
      borderRadius: BorderRadius.zero,
      // The value is part of what the row says ("Name, Test Driver").
      semanticLabel: [title, if (subtitle != null) subtitle!, if (value != null) value!].join(', '),
      child: row,
    );
  }
}

/// A label on the left and its value on the right — receipts and summaries.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasise = false,
    this.valueColor,
    this.labelColor,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.sm),
  });

  final String label;
  final String value;
  final bool emphasise;
  final Color? valueColor;
  final Color? labelColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasise
                  ? context.text.titleLarge
                  : context.text.bodyLarge?.copyWith(
                      color: labelColor ?? AppColors.inkSecondary,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Laid out at its own width so it always sits flush right; capped so
          // a long reference wraps instead of pushing the label off screen.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.55),
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: (emphasise ? context.text.titleLarge : context.text.bodyLarge)?.copyWith(
                color: valueColor ?? AppColors.ink,
                fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A text field in the house style: grey fill, black ring when focused, label
/// above rather than floating inside.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.prefixIcon,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.style,
    this.textAlign = TextAlign.start,
    this.autofillHints,
  });

  final String? label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final TextStyle? style;
  final TextAlign textAlign;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textAlign: textAlign,
      autofillHints: autofillHints,
      cursorColor: AppColors.ink,
      style: style ?? context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        helperText: helper,
        errorText: errorText,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: AppSizes.iconMd, color: AppColors.ink),
        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        prefix: prefix,
        suffixIcon: suffix,
        counterText: '',
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label!, style: context.text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        field,
      ],
    );
  }
}

enum BannerTone { info, warning, success, danger }

/// A tinted message block. Quiet: it informs, it does not shout.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.tone = BannerTone.info,
  });

  final String message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, IconData defaultIcon) = switch (tone) {
      BannerTone.info => (AppColors.ink, AppColors.fill, Icons.info_outline_rounded),
      BannerTone.warning => (AppColors.warning, AppColors.warningSoft, Icons.schedule_rounded),
      BannerTone.success => (AppColors.positive, AppColors.positiveSoft, Icons.check_circle_outline_rounded),
      BannerTone.danger => (AppColors.negative, AppColors.negativeSoft, Icons.error_outline_rounded),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadius.card),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon ?? defaultIcon, size: AppSizes.iconSm + 2, color: fg),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) ...[
                    Text(title!, style: context.text.titleSmall?.copyWith(color: fg)),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message,
                    style: context.text.bodyMedium?.copyWith(
                      color: tone == BannerTone.info ? AppColors.inkSecondary : fg,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Pressable(
                      onTap: onAction,
                      depth: PressDepth.firm,
                      tint: false,
                      borderRadius: AppRadius.chip,
                      semanticLabel: actionLabel,
                      child: Text(
                        actionLabel!,
                        style: context.text.labelMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: fg,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens a modal bottom sheet with the house grabber and safe-area handling.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isScrollControlled = true,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // Above the tab bar, like every sheet in a mobility app — not inside the tab.
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => child,
  );
}

/// Grabber + title + close, for the top of a modal sheet.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.showClose = true,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetGrabber(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageInset,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: context.text.headlineMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: context.text.bodyMedium),
                    ],
                  ],
                ),
              ),
              if (actionLabel != null && onAction != null)
                TertiaryButton(label: actionLabel!, onPressed: onAction),
              if (showClose)
                CircleButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  size: 36,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A bar pinned to the bottom of a screen holding its primary action.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child, this.divider = true});

  final Widget child;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: divider ? const Border(top: BorderSide(color: AppColors.line)) : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageInset,
            AppSpacing.md,
            AppSpacing.pageInset,
            AppSpacing.md,
          ),
          child: child,
        ),
      ),
    );
  }
}

void showToast(BuildContext context, String message, {Duration? duration}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      // Long enough to read: "Booking cancelled." needs far less time than
      // "Payments are not available right now. Please try again shortly."
      duration: duration ??
          Duration(milliseconds: (1500 + message.length * 60).clamp(3000, 7000)),
    ));
}
