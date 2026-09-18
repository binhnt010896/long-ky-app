import 'package:flutter/material.dart' show TextTheme;
import 'package:flutter/widgets.dart';

import 'vs_colors.dart';

/// Typography for Việt Sử.
///
/// Two families, straight from the visual reference:
///  - **Playfair Display** (serif) for display, titles and italic chronicle
///    pull-quotes — the "voice" of the app.
///  - **Be Vietnam Pro** (sans) for body copy, kickers and UI. Chosen because it
///    covers the full Vietnamese diacritic range cleanly.
///
/// Both families are **bundled as assets** (see this package's `pubspec.yaml`),
/// not fetched at runtime — the app must render every diacritic offline, so the
/// font binaries ship with it. The family names here must match the pubspec.
///
/// The design specifies tracking in `em`; Flutter's `letterSpacing` is in logical
/// pixels, so [track] converts `em × fontSize`. Every style below carries its
/// diacritics — never strip them.
abstract final class VSType {
  const VSType._();

  static const String familyDisplay = 'Playfair Display';
  static const String familyBody = 'Be Vietnam Pro';

  /// Convert an `em` tracking value to Flutter's pixel `letterSpacing`.
  static double track(double em, double fontSize) => em * fontSize;

  static TextStyle _display(
    double size, {
    FontWeight weight = FontWeight.w600,
    double height = 1.0,
    double emTracking = 0.0,
    bool italic = false,
    Color color = VSColors.inkPrimary,
  }) {
    return TextStyle(
      fontFamily: familyDisplay,
      fontSize: size,
      fontWeight: weight,
      // Playfair Display is a variable font; drive the wght axis explicitly so
      // the requested weight renders regardless of platform matching.
      fontVariations: <FontVariation>[
        FontVariation('wght', weight.value.toDouble()),
      ],
      height: height,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: track(emTracking, size),
      color: color,
    );
  }

  static TextStyle _body(
    double size, {
    FontWeight weight = FontWeight.w400,
    double height = 1.5,
    double emTracking = 0.0,
    Color color = VSColors.inkBody,
  }) {
    return TextStyle(
      fontFamily: familyBody,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: track(emTracking, size),
      color: color,
    );
  }

  // --- Display (Playfair) ---------------------------------------------------

  /// System / brand title (`Việt Sử`, 66px).
  static TextStyle get displayLarge =>
      _display(66, height: 0.95, emTracking: 0.02);

  /// Home hero era title (46px).
  static TextStyle get hero => _display(46, height: 1.02);

  /// Era-hub centred hero (44px).
  static TextStyle get hub => _display(44, height: 1.04);

  /// Event-detail headline (30px).
  static TextStyle get headline => _display(30, height: 1.08);

  /// Section / screen title (20px) — timeline header, hub subhead.
  static TextStyle get title => _display(20, height: 1.1);

  /// Timeline event-card title (17px).
  static TextStyle get cardTitle => _display(17, height: 1.2);

  /// Italic chronicle pull-quote (20px) — the app's recurring signature.
  static TextStyle get pullQuote =>
      _display(20, height: 1.42, italic: true, color: VSColors.inkPrimary);

  /// Italic era subtitle / tagline (19px).
  static TextStyle get subtitleItalic =>
      _display(19, height: 1.4, italic: true, color: VSColors.inkSecondary);

  // --- Body & UI (Be Vietnam Pro) -------------------------------------------

  /// Reading body (14px, generous 1.72 leading).
  static TextStyle get body => _body(14, height: 1.72, color: VSColors.inkBody);

  /// Secondary body / card supporting line (12.5px).
  static TextStyle get bodySmall =>
      _body(12.5, height: 1.5, color: VSColors.inkMuted);

  /// Caption / meta (12px), lightly tracked.
  static TextStyle get caption =>
      _body(12, height: 1.4, emTracking: 0.1, color: VSColors.inkMuted);

  /// Kicker above a hero — bright gold, uppercase, wide tracking (11px/.34em).
  static TextStyle get kicker => _body(
        11,
        weight: FontWeight.w500,
        emTracking: 0.34,
        color: VSColors.goldBright,
      );

  /// Overline / section label — gold, uppercase (10.5px/.32em).
  static TextStyle get overline => _body(
        10.5,
        weight: FontWeight.w500,
        emTracking: 0.32,
        color: VSColors.gold,
      );

  /// Date / range label next to a hairline (13px/.18em, gold).
  static TextStyle get label => _body(
        13,
        weight: FontWeight.w500,
        emTracking: 0.18,
        color: VSColors.gold,
      );

  /// Monospaced provenance caption on illustrations (10.5px).
  static TextStyle get provenance => const TextStyle(
        fontFamily: familyBody,
        fontSize: 10.5,
        height: 1.3,
        letterSpacing: 1.05, // 0.1em × 10.5
        color: VSColors.inkMuted,
      );

  /// Material [TextTheme] built from the semantic styles, so stock widgets
  /// inherit the system without every call site reaching for a named style.
  static TextTheme textTheme() {
    return TextTheme(
      displayLarge: displayLarge,
      displayMedium: hero,
      displaySmall: hub,
      headlineMedium: headline,
      titleLarge: title,
      titleMedium: cardTitle,
      bodyLarge: body,
      bodyMedium: bodySmall,
      bodySmall: caption,
      labelLarge: label,
      labelMedium: overline,
      labelSmall: kicker,
    );
  }
}
