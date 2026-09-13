// ─────────────────────────────────────────────────────────────────────────────
// BOOT SCREEN
//
// Shown only while a session is being restored — typically a few hundred
// milliseconds, and only when there is genuine work to wait for.
//
// Replaces a 5.8-second scripted splash (2 200 ms logo scale + 2 000 ms text slide
// + 1 600 ms hold, no skip) that ran on EVERY cold start. It was not waiting on
// anything: the app stored no session, so there was nothing to restore. Users paid
// nearly six seconds to reach a login screen and retype their phone number.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('PARQX', style: AppTypography.wordmark(size: 40, color: AppColors.brand)),
            const SizedBox(height: AppSpacing.xxl),
            // Deliberately understated: a thin bar reads as "a moment" where a large
            // spinner reads as "a problem".
            SizedBox(
              width: 96,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: context.colors.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation(AppColors.brand),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
