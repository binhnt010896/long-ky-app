import 'package:flutter/widgets.dart';

/// Core, era-independent colours of the Việt Sử sơn mài (lacquer) system.
///
/// Values are lifted verbatim from the visual reference (`Việt Sử.dc.html`):
/// deep lacquer grounds, a gold that runs from muted to bright, and a warm
/// parchment ink. Per-era accent colours live in [VSEraPalette] instead — this
/// class only holds what is shared by every screen and era.
///
/// Do not read raw opacities off these constants ad hoc; prefer the semantic
/// `ink*` roles below, which encode the exact parchment alphas the design uses.
abstract final class VSColors {
  const VSColors._();

  // --- Lacquer grounds (dark, deep-to-raised) -------------------------------
  /// Deepest well — status-bar edges, the very bottom of a scene.
  static const Color lacquerVoid = Color(0xFF060D0C);

  /// The deepest lacquer used as a scene's top stop.
  static const Color lacquerDeep = Color(0xFF050C0B);

  /// Canonical app background (`#07100f`).
  static const Color lacquer = Color(0xFF07100F);

  /// Slightly raised lacquer — foreground panels, silhouetted foreground hills.
  static const Color lacquerRaised = Color(0xFF0A140F);

  // --- Gold (the through-line: spines, accents, CTAs) -----------------------
  /// Primary gold — hairlines, kickers, borders, links.
  static const Color gold = Color(0xFFC9A24B);

  /// Bright gold — active/lit state, glow, gradient highlight end.
  static const Color goldBright = Color(0xFFE6C877);

  /// The signature gold sheen, used on the progress spine and CTA edges.
  /// Bright → primary, matching the design's `linear-gradient(#e6c877,#C9A24B)`.
  static const LinearGradient goldSheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldBright, gold],
  );

  // --- Parchment ink (warm off-white on lacquer) ----------------------------
  /// Full-strength ink (`#f2ead9`) — display type, primary content.
  static const Color parchment = Color(0xFFF2EAD9);

  /// Primary readable ink.
  static const Color inkPrimary = parchment;

  /// Emphasised secondary ink — subtitles, active pull-quotes (~.85 alpha).
  static const Color inkSecondary = Color(0xD9F2EAD9); // parchment @ 0.85

  /// Body copy on a dark scene (~.78 alpha).
  static const Color inkBody = Color(0xC7F2EAD9); // parchment @ 0.78

  /// Quiet supporting ink — captions, meta (~.6 alpha).
  static const Color inkMuted = Color(0x99F2EAD9); // parchment @ 0.6

  /// Faint ink — inactive dots, disabled labels (~.42 alpha).
  static const Color inkFaint = Color(0x6BF2EAD9); // parchment @ 0.42

  /// Hairline ink — dividers and 1px separators on lacquer (~.14 alpha).
  static const Color inkHairline = Color(0x24F2EAD9); // parchment @ 0.14

  // --- Gold at working alphas (borders / washes) ----------------------------
  /// Gold hairline border (~.28 alpha) — citation cards, chrome outlines.
  static const Color goldBorder = Color(0x47C9A24B); // gold @ 0.28

  /// Gold wash fill (~.06 alpha) — citation card background.
  static const Color goldWash = Color(0x0FC9A24B); // gold @ 0.06

  /// Gold glow colour for shadows around lit nodes and the spine.
  static const Color goldGlow = Color(0xB3E6C877); // goldBright @ 0.7

  /// Parse a `#RRGGBB` (or `RRGGBB`) hex string into an opaque [Color].
  static Color fromHex(String hex) {
    var v = hex.trim();
    if (v.startsWith('#')) v = v.substring(1);
    if (v.length == 6) v = 'FF$v';
    return Color(int.parse(v, radix: 16));
  }
}
