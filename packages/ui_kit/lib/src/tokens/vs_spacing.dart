import 'package:flutter/widgets.dart';

/// Spacing scale — the rhythm of gaps and paddings across the app.
///
/// Derived from the recurring measures in the visual reference (screen padding
/// ~26–30px, card padding 15–18px, stacked gaps of 6/10/16px). Named by role and
/// size so layout code stays legible and consistent.
abstract final class VSSpacing {
  const VSSpacing._();

  static const double xxs = 4;
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 30;
  static const double huge = 44;

  /// Standard horizontal inset from a phone screen edge to content.
  static const double screenEdge = 26;

  /// Inset used inside timeline / citation cards.
  static const double cardInset = 18;

  /// Common `EdgeInsets` presets.
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: screenEdge);
  static const EdgeInsets card = EdgeInsets.symmetric(
    horizontal: cardInset,
    vertical: md,
  );
}

/// Corner radii — from the citation card (12) up to the phone frame (52).
abstract final class VSRadii {
  const VSRadii._();

  static const Radius citation = Radius.circular(12);
  static const Radius card = Radius.circular(14);
  static const Radius chip = Radius.circular(22);
  static const Radius pill = Radius.circular(30);
  static const Radius screen = Radius.circular(42);
  static const Radius device = Radius.circular(52);

  static const BorderRadius cardAll = BorderRadius.all(card);
  static const BorderRadius citationAll = BorderRadius.all(citation);
  static const BorderRadius pillAll = BorderRadius.all(pill);
}

/// Hairline widths. The design leans on crisp 1px gold/parchment rules.
abstract final class VSBorders {
  const VSBorders._();

  static const double hairline = 1;
  static const double node = 1.5;
  static const double spine = 3;
}

/// Motion durations and curves.
///
/// The ambient particle "drift" runs 7–18s; UI transitions (lang toggle, card
/// rise, tier fallbacks) are quick and eased. The parallax path itself is driven
/// per-frame elsewhere — these are for discrete state changes.
abstract final class VSMotion {
  const VSMotion._();

  /// Snappy control feedback (tab toggle, tap states) — matches the design's
  /// `transition:all .2s`.
  static const Duration control = Duration(milliseconds: 200);

  /// Event cards rising into view along the timeline.
  static const Duration reveal = Duration(milliseconds: 520);

  /// Scene / era cross-fades on swipe.
  static const Duration sceneFade = Duration(milliseconds: 640);

  /// Ambient particle drift cycle (mid-point of the 7–18s range).
  static const Duration drift = Duration(milliseconds: 12000);

  static const Curve standard = Curves.easeInOutCubic;
  static const Curve emphasized = Curves.easeOutCubic;
}
