// ─────────────────────────────────────────────────────────────────────────────
// COMMON WIDGETS
//
// Small pieces used across several screens. Anything used only once lives with its
// screen instead — a shared folder full of single-use widgets is worse than none.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'interaction.dart';
import 'surfaces.dart';

/// Section heading with an optional trailing action.
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
            AppSpacing.xl,
            AppSpacing.pageInset,
            AppSpacing.md,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: context.text.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Text field with a consistent label, error and helper treatment.
///
/// Always uses a floating `labelText` rather than hint-only, so the field's purpose
/// survives the user starting to type — the old plate field lost its label entirely.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
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
  });

  final String label;
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

  @override
  Widget build(BuildContext context) {
    return TextField(
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
      style: context.text.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        errorText: errorText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: AppSizes.iconMd),
        prefix: prefix,
        suffixIcon: suffix,
        // The character counter is noise on a phone or plate field.
        counterText: '',
      ),
    );
  }
}

/// Rounded surface used for grouped content.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.margin,
    this.borderColor,
    this.level = SurfaceLevel.raised,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  /// An outline, for the rare case where one carries meaning — a selected
  /// state, a destructive confirmation. Null everywhere else, deliberately:
  /// this used to default to `colors.outline`, so every card in the app was
  /// boxed and nothing could stand out by being boxed.
  final Color? borderColor;

  final SurfaceLevel level;

  /// Explicit surface. PARQX mixes dark and light surfaces inside one theme, so
  /// a card sometimes has to be told which ground it is sitting on.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final content = AppSurface(
      level: level,
      padding: padding,
      borderColor: borderColor,
      color: color,
      child: child,
    );

    if (onTap == null) {
      return Padding(padding: margin ?? EdgeInsets.zero, child: content);
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Pressable(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: content,
      ),
    );
  }
}

/// Label/value row used in summaries and receipts.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.emphasise = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData? icon;

  /// For the total line.
  final bool emphasise;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.iconSm, color: context.colors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
          ],
          // BOTH sides flex.
          //
          // The label was `Expanded` and the value was a bare `Text`, so a long
          // value — an address, a plate plus a date, a lot name — pushed the row
          // open and overflowed. Measured at 213px on the confirmation screen at
          // 360px width, in a widget used by every receipt and summary in the
          // app. It had never shown up because the fixtures reached by hand all
          // happened to have short values.
          //
          // The label yields first (it is the least informative half) and
          // ellipsises; the value keeps its space and wraps rather than being
          // cut, because a truncated amount or address is worse than a tall row.
          Flexible(
            flex: 4,
            child: Text(
              label,
              style: emphasise ? context.text.titleMedium : context.text.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Flexible(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: (emphasise ? context.text.titleLarge : context.text.titleSmall)?.copyWith(
                color: valueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Location line in the Home header.
///
/// Renders a real state — including "location off" — rather than silently showing
/// coordinates from a city the user may never have visited.
class LocationHeader extends StatelessWidget {
  const LocationHeader({
    super.key,
    required this.label,
    required this.onTap,
    this.isResolving = false,
    this.hasLocation = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool isResolving;
  final bool hasLocation;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.chip,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasLocation ? Icons.place_rounded : Icons.location_disabled_rounded,
              size: AppSizes.iconSm,
              color: hasLocation ? AppColors.brand : context.colors.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                isResolving ? 'Finding you…' : label,
                style: context.text.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: AppSizes.iconSm,
              color: context.colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline banner for a condition the user can resolve.
/// An inline notice.
///
/// Redrawn from a full-bleed tinted slab into a quiet card with a coloured rule
/// down its leading edge.
///
/// The slab version was the single loudest object on the old Home screen: a
/// full-width amber block for the entirely ordinary condition of location being
/// switched off. Tinted fills at that scale read as alarm regardless of what
/// they say, and they set the tone colour against the page rather than against
/// the message.
///
/// A 3px rule states the tone at a glance, an icon repeats it for anyone who
/// cannot see colour, and the body sits on the ordinary surface — so a notice
/// takes the room it needs and no more.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.info_outline_rounded,
    this.tone = BannerTone.info,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    // The tone's own colour, and the fill behind it.
    //
    // On dark the light "soft" tints are wrong twice over: too bright against a
    // near-black surface, and unreadable under the ink colour the dark theme
    // uses. So the dark build tints with the TONE colour at low alpha instead,
    // and lifts the foreground to a lighter step of the same hue. This widget is
    // shared byte-for-byte with the operator app, which is entirely dark.
    final dark = context.isDark;

    final (Color fg, Color bg) = switch (tone) {
      BannerTone.info => dark
          ? (const Color(0xFF7FB3FF), AppColors.info)
          : (AppColors.info, AppColors.infoSoft),
      BannerTone.warning => dark
          ? (const Color(0xFFE8A33D), AppColors.warning)
          : (AppColors.warning, AppColors.warningSoft),
      BannerTone.success => dark
          ? (AppColors.successBright, AppColors.success)
          : (AppColors.success, AppColors.successSoft),
      BannerTone.danger => dark
          ? (const Color(0xFFFF8098), AppColors.danger)
          : (AppColors.danger, AppColors.dangerSoft),
    };

    final fill = dark ? bg.withValues(alpha: 0.14) : bg.withValues(alpha: 0.55);
    final ink = dark ? AppColors.inkDark : AppColors.ink;

    return Semantics(
      liveRegion: true,
      child: ClipRRect(
        borderRadius: AppRadius.field,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: fg),
              Expanded(
                child: Container(
                  color: fill,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: AppSizes.iconSm, color: fg),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          message,
                          style: context.text.bodySmall?.copyWith(color: ink),
                        ),
                      ),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Pressable(
                          onTap: onAction,
                          depth: PressDepth.firm,
                          tint: false,
                          borderRadius: AppRadius.chip,
                          semanticLabel: actionLabel,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs + 2,
                            ),
                            child: Text(
                              actionLabel!,
                              style: context.text.labelMedium?.copyWith(
                                color: fg,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum BannerTone { info, warning, success, danger }

/// Consistent bottom sheet presentation.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isScrollControlled = true,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => child,
  );
}

/// Header for a bottom sheet: title, optional action, and a close button.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageInset,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.headlineSmall)),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}
