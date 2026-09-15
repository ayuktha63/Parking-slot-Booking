# Pre-transformation screens (quarantined, not compiled)

These are the original screens, kept for reference only. They were moved here out
of `lib/` during the premium UI transformation.

They were already unreachable: nothing under `lib/core`, `lib/features` or
`lib/shared` imported any of them. They formed a closed cluster that imported only
each other — but Dart compiles everything under `lib/`, so they were still being
analysed and built into every APK.

That had real costs, not just untidiness:

  * They each declared their own private `AppColors` class. Eleven disagreeing
    colour palettes is what the shared token system replaced; leaving these in
    `lib/` meant the old palettes were still in the binary.
  * They forced dependencies to stay in `pubspec.yaml`. The `google_fonts`
    package could not be removed — and Inter could not be bundled properly —
    while these files still imported it.
  * They forced `main.dart` to keep exporting a `pushSmooth()` navigation helper
    that no live screen called, purely so these files would keep analysing.

Restoring one is a `git mv` back into `lib/`; it will need its imports and its
local `AppColors` reconciled with `lib/core/theme/tokens.dart`.
