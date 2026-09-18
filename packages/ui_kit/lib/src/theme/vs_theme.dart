import 'package:flutter/material.dart';

import '../tokens/vs_colors.dart';
import '../tokens/vs_era_palette.dart';
import '../tokens/vs_typography.dart';

/// Theme extension that carries the **current era's palette** through the widget
/// tree. Widgets read `Theme.of(context).extension<VSEraTheme>()` (or the
/// [BuildContext.era] shortcut) instead of hardcoding colours, so the same
/// widget tree recolours per era — never branch on the era in code, branch on
/// this value.
@immutable
class VSEraTheme extends ThemeExtension<VSEraTheme> {
  const VSEraTheme({required this.palette});

  final VSEraPalette palette;

  @override
  VSEraTheme copyWith({VSEraPalette? palette}) =>
      VSEraTheme(palette: palette ?? this.palette);

  @override
  VSEraTheme lerp(covariant ThemeExtension<VSEraTheme>? other, double t) {
    if (other is! VSEraTheme) return this;
    // Interpolate the visible fields so era swaps cross-fade cleanly. Scene
    // stops are lerped stop-for-stop when the shape matches, else snapped.
    final a = palette;
    final b = other.palette;
    return VSEraTheme(
      palette: VSEraPalette(
        name: t < 0.5 ? a.name : b.name,
        accent: Color.lerp(a.accent, b.accent, t)!,
        accentBright: Color.lerp(a.accentBright, b.accentBright, t)!,
        particle: Color.lerp(a.particle, b.particle, t)!,
        horizonGlow: Color.lerp(a.horizonGlow, b.horizonGlow, t)!,
        sceneStops: _lerpStops(a.sceneStops, b.sceneStops, t),
      ),
    );
  }

  static List<Color> _lerpStops(List<Color> a, List<Color> b, double t) {
    if (a.length != b.length) return t < 0.5 ? a : b;
    return <Color>[
      for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!,
    ];
  }
}

/// Builds the Việt Sử [ThemeData].
///
/// One dark, lacquer-grounded theme for the whole app. The [era] palette is
/// threaded in as a [VSEraTheme] extension; pass the loaded era's palette so the
/// tree recolours, or omit it for the founding-era default.
abstract final class VSTheme {
  const VSTheme._();

  static ThemeData build({
    VSEraPalette era = VSEraPalette.fallback,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: VSColors.gold,
      brightness: Brightness.dark,
    ).copyWith(
      surface: VSColors.lacquer,
      onSurface: VSColors.inkPrimary,
      primary: VSColors.gold,
      onPrimary: VSColors.lacquerRaised,
      secondary: era.accent,
      onSecondary: VSColors.inkPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: VSColors.lacquer,
      canvasColor: VSColors.lacquer,
      textTheme: VSType.textTheme(),
      dividerColor: VSColors.inkHairline,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[
        VSEraTheme(palette: era),
      ],
    );
  }
}

/// Ergonomic reads off the current theme.
extension VSThemeContext on BuildContext {
  /// The current era palette, falling back to the founding era if unset.
  VSEraPalette get era =>
      Theme.of(this).extension<VSEraTheme>()?.palette ?? VSEraPalette.fallback;
}
