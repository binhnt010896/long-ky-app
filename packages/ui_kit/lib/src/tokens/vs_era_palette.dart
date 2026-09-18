import 'package:flutter/widgets.dart';

import 'vs_colors.dart';

/// The colour identity of a single historical era.
///
/// Gold and parchment are shared across the whole app ([VSColors]); what a scene
/// changes from era to era is its **accent** and the vertical **scene gradient**
/// that paints the sky→land backdrop behind the parallax layers.
///
/// Content is data, not code: an era's accent arrives from `content/eras/*.json`,
/// so [VSEraPalette.fromAccent] derives a coherent palette from a single hex
/// value. The named presets ([hongBangVanLang], [jade], [river], [terracotta])
/// are the design-reference defaults and the fallbacks when JSON omits colour.
@immutable
class VSEraPalette {
  const VSEraPalette({
    required this.name,
    required this.accent,
    required this.accentBright,
    required this.particle,
    required this.sceneStops,
    required this.horizonGlow,
  });

  /// Human-facing key (slug), e.g. `hong-bang-van-lang`. Not shown to users.
  final String name;

  /// The era's signature colour — dots, kickers, sliver tints.
  final Color accent;

  /// A lifted, luminous form of [accent] for glow and active states.
  final Color accentBright;

  /// Colour of the drifting ambient particles for this era (flagship only).
  final Color particle;

  /// Top-to-bottom gradient stops for the scene backdrop (sky → horizon → land).
  /// Ordered from the top of the screen downward.
  final List<Color> sceneStops;

  /// The warm/luminous glow that pools at the horizon line of the scene.
  final Color horizonGlow;

  /// The scene backdrop as a paintable vertical gradient.
  LinearGradient get sceneGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: sceneStops,
      );

  /// Derive a full era palette from a single accent hex (the JSON-driven path).
  ///
  /// [accentHex] accepts `#RRGGBB` or `RRGGBB`. The scene is built by grading the
  /// accent down into the shared lacquer grounds, so any era colour yields a
  /// backdrop that still reads as sơn mài.
  factory VSEraPalette.fromAccent(String name, String accentHex,
      {Color? particle}) {
    final accent = _parseHex(accentHex);
    final bright = _lift(accent, 0.28);
    return VSEraPalette(
      name: name,
      accent: accent,
      accentBright: bright,
      particle: particle ?? bright,
      sceneStops: <Color>[
        VSColors.lacquerDeep,
        Color.alphaBlend(accent.withValues(alpha: 0.10), VSColors.lacquer),
        Color.alphaBlend(accent.withValues(alpha: 0.34), VSColors.lacquer),
        Color.alphaBlend(VSColors.gold.withValues(alpha: 0.22), accent),
        VSColors.lacquerRaised,
      ],
      horizonGlow: VSColors.goldBright.withValues(alpha: 0.5),
    );
  }

  /// Copy with overrides — used when JSON supplies some but not all colours.
  VSEraPalette copyWith({
    String? name,
    Color? accent,
    Color? accentBright,
    Color? particle,
    List<Color>? sceneStops,
    Color? horizonGlow,
  }) {
    return VSEraPalette(
      name: name ?? this.name,
      accent: accent ?? this.accent,
      accentBright: accentBright ?? this.accentBright,
      particle: particle ?? this.particle,
      sceneStops: sceneStops ?? this.sceneStops,
      horizonGlow: horizonGlow ?? this.horizonGlow,
    );
  }

  // --- Design-reference presets ---------------------------------------------

  /// Hồng Bàng & Văn Lang — the founding era. Jade dawn rising into a gold
  /// horizon, lifted straight from the `01 · Home` scene gradient.
  static const VSEraPalette hongBangVanLang = VSEraPalette(
    name: 'hong-bang-van-lang',
    accent: Color(0xFF5F8F74), // jade
    accentBright: Color(0xFF8FB89A),
    particle: Color(0xFFE6C877), // gold motes over the dawn
    sceneStops: <Color>[
      Color(0xFF050C0B),
      Color(0xFF081310),
      Color(0xFF0E211B),
      Color(0xFF233A2A),
      Color(0xFF5C5330),
      Color(0xFF8A6F38),
      Color(0xFF5A4A28),
    ],
    horizonGlow: Color(0x80E6C877), // goldBright @ 0.5
  );

  /// Jade — default for early/founding eras.
  static const VSEraPalette jade = VSEraPalette(
    name: 'jade',
    accent: Color(0xFF5F8F74),
    accentBright: Color(0xFF8FB89A),
    particle: Color(0xFF8FB89A),
    sceneStops: <Color>[
      Color(0xFF07100F),
      Color(0xFF0B1A15),
      Color(0xFF12241C),
      Color(0xFF0A140F),
    ],
    horizonGlow: Color(0x335F8F74),
  );

  /// River — cool blue eras (e.g. Nhà Trần in the global timeline).
  static const VSEraPalette river = VSEraPalette(
    name: 'river',
    accent: Color(0xFF4A7C9B),
    accentBright: Color(0xFF8FB8CF),
    particle: Color(0xFFA8CBE0),
    sceneStops: <Color>[
      Color(0xFF050B12),
      Color(0xFF0F2433),
      Color(0xFF1C3F52),
      Color(0xFF0A1620),
    ],
    horizonGlow: Color(0x384A7C9B),
  );

  /// Terracotta — warm earthen eras (e.g. Nhà Lê sơ).
  static const VSEraPalette terracotta = VSEraPalette(
    name: 'terracotta',
    accent: Color(0xFFB5734A),
    accentBright: Color(0xFFD79A6E),
    particle: Color(0xFFD79A6E),
    sceneStops: <Color>[
      Color(0xFF0B0705),
      Color(0xFF2A1E12),
      Color(0xFF3A2A1A),
      Color(0xFF170F08),
    ],
    horizonGlow: Color(0x38B5734A),
  );

  /// The safe default when no era context is available.
  static const VSEraPalette fallback = hongBangVanLang;

  @override
  bool operator ==(Object other) =>
      other is VSEraPalette &&
      other.name == name &&
      other.accent == accent &&
      other.accentBright == accentBright &&
      other.particle == particle &&
      other.horizonGlow == horizonGlow &&
      _listEquals(other.sceneStops, sceneStops);

  @override
  int get hashCode => Object.hash(
        name,
        accent,
        accentBright,
        particle,
        horizonGlow,
        Object.hashAll(sceneStops),
      );
}

// --- helpers ----------------------------------------------------------------

Color _parseHex(String hex) {
  var v = hex.trim();
  if (v.startsWith('#')) v = v.substring(1);
  if (v.length == 6) v = 'FF$v';
  final value = int.parse(v, radix: 16);
  return Color(value);
}

/// Lift a colour toward light by [amount] (0..1), keeping alpha.
Color _lift(Color c, double amount) {
  return Color.lerp(c, const Color(0xFFFFFFFF), amount)!.withValues(alpha: 1);
}

bool _listEquals(List<Color> a, List<Color> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
