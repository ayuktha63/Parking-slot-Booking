// ─────────────────────────────────────────────────────────────────────────────
// BOOT
//
// Shown only while the stored session is being restored — usually a few hundred
// milliseconds. The wordmark on white, the same thing the launcher showed.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import 'parqx_controls.dart';

class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ParqxWordmark(size: 30),
            SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: 72,
              child: ClipRRect(
                borderRadius: AppRadius.chip,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: AppColors.fill,
                  valueColor: AlwaysStoppedAnimation(AppColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
