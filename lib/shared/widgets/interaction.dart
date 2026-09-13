// ─────────────────────────────────────────────────────────────────────────────
// INTERACTION PRIMITIVES
//
// The replacement for Material's ink ripple, which `AppTheme` switches off
// globally.
//
// WHY REPLACE IT AT ALL
//   The ripple is a good interaction and a terrible signature. It is the single
//   most recognisable Material gesture: a circle expanding from the touch point,
//   with `InkSparkle` adding a shader glitter on Android. Any product using it
//   unmodified is telling every user it was built with the platform's default
//   widget kit — which was the brief's complaint in one sentence.
//
//   It also cannot express what PARQX needs it to. A ripple is uniform: tapping
//   a disabled slot and tapping an available one ripple identically. Feedback
//   here differentiates by outcome.
//
// WHAT REPLACES IT
//   Physical response. The surface compresses under the finger (the press) and
//   springs back on release — the same model as a real button. It is paired with
//   a haptic keyed to MEANING rather than to strength (see core/utils/haptics),
//   and a low-opacity tint so the feedback survives for users who have asked the
//   OS to reduce motion.
//
// ACCESSIBILITY
//   `Pressable` is a semantic button with a merged label, so a screen reader
//   announces it once rather than reading each text fragment inside it. Motion is
//   suppressed under `MediaQuery.disableAnimations`, and the tint remains — a
//   press must never be invisible.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/haptics.dart';

/// How firmly a press compresses its target.
///
/// Larger elements need a *smaller* ratio to feel equally pressed: a 4% squeeze
/// on a full-width card is a big visual move, while the same 4% on a 38px chip is
/// barely perceptible. Matching the ratio to the size is what makes a screen of
/// mixed controls feel like one surface.
enum PressDepth {
  /// Chips, small tiles, icon buttons.
  firm(0.93),

  /// Cards, list rows, sheet items.
  standard(0.975),

  /// Full-width primary actions and whole-screen surfaces.
  subtle(0.985);

  const PressDepth(this.scale);
  final double scale;
}

/// What a tap on this element means, which decides how it feels.
enum PressFeedback {
  /// A choice that lands — selecting a slot, switching vehicle, applying a
  /// filter. The default.
  selection,

  /// Navigation or opening something. Silent: haptics are for commitments, and
  /// buzzing on every tap trains users to ignore the buzz that matters.
  none,

  /// A reversible dismissal — closing a sheet, clearing a field.
  light,

  /// A commitment succeeding. Rare, and never fired speculatively: only after
  /// the server has actually said yes.
  success,

  /// A refusal — tapping something unavailable.
  refusal;
}

/// A tappable surface with physical press feedback.
///
/// Use this instead of `InkWell` for anything that is a *thing* — a card, a
/// chip, a tile, a row. `InkWell` still makes sense inside dense text where a
/// scale would be distracting; that is the exception, not the rule.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.depth = PressDepth.standard,
    this.feedback = PressFeedback.none,
    this.borderRadius,
    this.semanticLabel,
    this.enabled = true,
    this.tint = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final PressDepth depth;
  final PressFeedback feedback;

  /// Shape of the press tint. Match the child's own radius, or the tint will
  /// square off a rounded card's corners.
  final BorderRadius? borderRadius;

  /// Collapses the subtree into one semantic button with this label. Leave null
  /// to let the child's own semantics through (correct when the child already
  /// composes a good label, as `ParkingCard` does).
  final String? semanticLabel;

  final bool enabled;

  /// The darkening overlay on press. Disable on surfaces that are already dark
  /// or that carry imagery, where it muddies rather than clarifies.
  final bool tint;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.press,
    reverseDuration: AppMotion.quick,
  );

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (!_interactive) return;
    if (pressed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _handleTap() {
    switch (widget.feedback) {
      case PressFeedback.selection:
        Haptics.selection();
      case PressFeedback.light:
        Haptics.light();
      case PressFeedback.success:
        Haptics.success();
      case PressFeedback.refusal:
        Haptics.refusal();
      case PressFeedback.none:
        break;
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? AppRadius.card;
    // Motion is the primary channel, but it cannot be the only one: a user who
    // has switched animation off still has to be able to see a press land.
    final reduceMotion = context.reduceMotion;

    Widget content = widget.child;

    if (widget.tint) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Opacity(
                  // Heavier when motion is off, so the press is still legible.
                  opacity: _controller.value * (reduceMotion ? 0.10 : 0.055),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.shadowTint,
                      borderRadius: radius,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!reduceMotion) {
      final scale = Tween<double>(begin: 1, end: widget.depth.scale).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOut,
          reverseCurve: AppMotion.spring,
        ),
      );
      content = ScaleTransition(scale: scale, child: content);
    }

    content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _interactive ? _handleTap : null,
      onLongPress: _interactive ? widget.onLongPress : null,
      child: content,
    );

    if (widget.semanticLabel != null) {
      return Semantics(
        button: true,
        enabled: _interactive,
        label: widget.semanticLabel,
        // The label is composed; reading the fragments again would repeat it.
        excludeSemantics: true,
        child: content,
      );
    }

    return Semantics(button: _interactive, enabled: _interactive, child: content);
  }
}

/// Fades and lifts a child into place on first build.
///
/// For content that arrives asynchronously — a results list replacing a
/// skeleton, a card appearing after a fetch. A list that pops into existence
/// fully-formed reads as a repaint; one that rises reads as an arrival.
///
/// `index` staggers siblings. It is capped deliberately: past about the eighth
/// item the delay stops reading as choreography and starts reading as lag, and
/// items below the fold would animate where nobody can see them anyway.
class EntranceFade extends StatefulWidget {
  const EntranceFade({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 12,
  });

  final Widget child;
  final int index;
  final double offset;

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
  );

  @override
  void initState() {
    super.initState();
    final delay = AppMotion.stagger * widget.index.clamp(0, 8);
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(delay).then((_) {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return widget.child;

    final curved = CurvedAnimation(parent: _controller, curve: AppMotion.standard);
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - curved.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Cross-fades between values of a changing number without the layout jumping.
///
/// Used for live availability counts, which change under the user from socket
/// events. A count that swaps instantly is easy to miss; one that swaps with a
/// short fade tells the user something updated without demanding attention.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.builder,
  });

  final int value;
  final Widget Function(BuildContext context, int value) builder;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.quick,
      switchInCurve: AppMotion.standard,
      // Sized by the largest child so a 9 → 10 transition does not shove
      // everything beside it sideways mid-fade.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, if (current != null) current],
      ),
      child: KeyedSubtree(key: ValueKey(value), child: builder(context, value)),
    );
  }
}
