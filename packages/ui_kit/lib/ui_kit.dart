/// Việt Sử design system — the visual token + theme layer.
///
/// Import this one file to reach the whole system:
///   import 'package:ui_kit/ui_kit.dart';
///
/// Tokens ([VSColors], [VSEraPalette], [VSType], [VSSpacing], [VSRadii],
/// [VSBorders], [VSMotion]) describe the sơn mài language; [VSTheme] assembles
/// them into a [ThemeData] and threads the current era via [VSEraTheme].
library;

export 'src/theme/vs_theme.dart';
export 'src/tokens/vs_colors.dart';
export 'src/tokens/vs_era_palette.dart';
export 'src/tokens/vs_spacing.dart';
export 'src/tokens/vs_typography.dart';
