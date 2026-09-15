// ─────────────────────────────────────────────────────────────────────────────
// LIVE DURATION
//
// A per-second clock for an active parking session.
//
// WHY THIS EXISTS
//   Active Parking is the screen the brief singles out as a signature surface — it
//   should feel like the product is accompanying the driver. It rendered
//   `"1h 24m elapsed"`: a static string at minute granularity that only changed when
//   a provider happened to refetch. Watched for thirty seconds it does not move at
//   all, so the one screen that most needs to feel live felt frozen.
//
// WHERE THE TRUTH LIVES — this does NOT move business logic to the client
//   The SERVER owns the facts: `checked_in_at` is the authoritative instant the
//   session began, and `projected_total_paise` is what the stay costs, computed by
//   the same function that settles the bill at check-out.
//
//   This widget only renders the passage of time since a timestamp the server gave
//   it. It never computes money, never decides whether a session is overstaying, and
//   never writes anything back. Elapsed time is arithmetic on a server timestamp, not
//   a business rule — and the alternative (polling the server once a second to be
//   told what a clock can work out locally) would be worse for both parties.
//
// A NOTE FOR TEST AUTHORS
//   This widget holds a periodic timer while it is on screen, so `pumpAndSettle`
//   on a tree containing an ACTIVE parked booking will never return — there is
//   always another frame scheduled. Use `pump(duration)` for those screens. This is
//   correct production behaviour, not a bug to design around.
//
// CORRECTNESS
//   - ticks on a 1s timer, cancelled on dispose — no leaked timers
//   - rebuilds only this subtree, never the screen
//   - tabular figures, so the digits do not jitter as they change width
//   - clamps at zero: a clock skew that puts check-in slightly in the future shows
//     0:00 rather than a negative duration
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/typography.dart';

/// Formats a duration as a running clock: `04:21` under an hour, `1:04:21` over.
String formatElapsed(Duration d, {bool alwaysHours = false}) {
  final seconds = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');

  // `alwaysHours` for the big Active Parking clock.
  //
  // Without it the first hour of a session reads "00:26", which is ambiguous in
  // exactly the situation where it matters: is that twenty-six minutes, or
  // twenty-six seconds? A leading "00:" costs two characters and removes the
  // question. Elsewhere — a compact strip, a list row — the shorter form is
  // better, so this is opt-in.
  if (alwaysHours) {
    return '${h.toString().padLeft(2, '0')}:$mm:$ss';
  }
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Ticks once a second from [since], rebuilding only itself.
class LiveDuration extends StatefulWidget {
  const LiveDuration({
    super.key,
    required this.since,
    this.style,
    this.builder,
    this.alwaysHours = false,
  });

  /// The server's authoritative start instant.
  final DateTime since;

  /// Renders as HH:MM:SS even under an hour. See [formatElapsed].
  final bool alwaysHours;

  final TextStyle? style;

  /// Optional custom rendering — used where the elapsed time is part of a sentence
  /// rather than a standalone clock.
  final Widget Function(BuildContext context, Duration elapsed)? builder;

  @override
  State<LiveDuration> createState() => _LiveDurationState();
}

class _LiveDurationState extends State<LiveDuration> with WidgetsBindingObserver {
  Timer? _timer;
  late Duration _elapsed = _compute();

  Duration _compute() {
    final d = DateTime.now().difference(widget.since);
    return d.isNegative ? Duration.zero : d;
  }

  void _startTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = _compute());
    });
  }

  void _stopTicking() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTicking();
  }

  /// Stops the clock while the app is in the background.
  ///
  /// A per-second `setState` behind a backgrounded app is pure waste — nobody is
  /// looking at it. Because every tick recomputes from the server's `since` rather
  /// than incrementing a counter, coming back after ten minutes shows the correct
  /// elapsed time immediately rather than resuming ten minutes behind.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => _elapsed = _compute());
      _startTicking();
    } else {
      _stopTicking();
    }
  }

  @override
  void didUpdateWidget(LiveDuration oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The server re-issued a different check-in instant (a correction, or a
    // different booking rendered into the same slot in the tree).
    if (oldWidget.since != widget.since) _elapsed = _compute();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final custom = widget.builder;
    if (custom != null) return custom(context, _elapsed);

    final text = formatElapsed(_elapsed, alwaysHours: widget.alwaysHours);

    return Semantics(
      // Spoken as words; "01:24:18" is read as three numbers otherwise.
      label: _spoken(_elapsed),
      excludeSemantics: true,
      child: Text(
        text,
        style: widget.style ??
            AppTypography.numeric(size: 34, weight: FontWeight.w700)
                .copyWith(color: context.colors.onSurface),
      ),
    );
  }

  static String _spoken(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0 && m == 0) return 'just started';
    final parts = <String>[];
    if (h > 0) parts.add('$h hour${h == 1 ? '' : 's'}');
    if (m > 0) parts.add('$m minute${m == 1 ? '' : 's'}');
    return '${parts.join(' ')} parked';
  }
}
