// ─────────────────────────────────────────────────────────────────────────────
// JOURNEY PROGRESS
//
// Three segments under the app bar, telling the customer where they are in a
// booking without turning the flow into a checkout wizard.
//
// ─────────────────────────────────────────────────────────────────────────────
// WHY IT IS THIS SMALL
//
// A numbered stepper with labelled circles and connecting lines is the obvious
// thing to build and the wrong one here. It costs 60–80px of vertical space at
// the top of every screen in the flow, it competes with the screen's own title,
// and it makes a two-minute task look like a form to be endured.
//
// What the customer actually needs is an answer to "how much more of this is
// there" — which is a proportion, not a diagram. Three bars answer it in the
// height of a divider.
//
// The labels are there for screen readers and for the current step only. A row
// of three visible words would reintroduce the wizard.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

enum BookingStep {
  /// Choosing the bay and the window.
  slot('Choose a slot'),

  /// Confirming the details and the price.
  review('Review'),

  /// Paying.
  pay('Payment');

  const BookingStep(this.label);

  final String label;

  /// NB: position comes from `Enum.index`, which every enum already has — a
  /// field of that name is illegal on an enum, and declaring one is how this
  /// first failed to compile.
  static int get count => BookingStep.values.length;
}

class JourneyProgress extends StatelessWidget {
  const JourneyProgress({super.key, required this.step});

  final BookingStep step;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Spoken as a position, because that is what it means.
      label: 'Step ${step.index + 1} of ${BookingStep.count}: ${step.label}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageInset,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            for (var i = 0; i < BookingStep.count; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: AnimatedContainer(
                  duration: AppMotion.normal,
                  curve: AppMotion.standard,
                  height: 3,
                  decoration: BoxDecoration(
                    // Steps already passed stay lit: the bar shows progress
                    // made, not just the current position.
                    color: i <= step.index
                        ? AppColors.brand
                        : AppColors.surfaceAltDark,
                    borderRadius: AppRadius.chip,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
