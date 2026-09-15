// ─────────────────────────────────────────────────────────────────────────────
// ENTRY CODE
//
// The booking code the operator looks up at the gate. Large, selectable and
// copyable — it is the one thing a customer must be able to produce on arrival.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/surfaces.dart';

class EntryCodeCard extends StatelessWidget {
  const EntryCodeCard({super.key, required this.code, this.caption = 'Show this code at the entrance'});

  final String code;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      level: SurfaceLevel.outlined,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.confirmation_number_outlined, size: 18, color: AppColors.inkSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(caption, style: context.text.bodyMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  // Plain text, as on the confirmation: Copy covers copying.
                  child: Text(code, style: AppTypography.code(size: 32, spacing: 2.5)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              PillButton(
                label: 'Copy',
                icon: Icons.copy_rounded,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) showToast(context, 'Booking code copied');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
