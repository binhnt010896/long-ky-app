import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'cms.themeMode';
const _seedColorKey = 'cms.seedColor';

/// A few named picks, not a full colour wheel — this is an internal tool,
/// not something worth a custom-colour picker for. `slate` is the default:
/// neutral, so it doesn't read as "pink" the way the brand oxblood's
/// Material3-derived tones did.
enum CmsAccent {
  slate(Color(0xFF445566), 'Slate'),
  blue(Color(0xFF2563EB), 'Blue'),
  teal(Color(0xFF0F766E), 'Teal'),
  green(Color(0xFF2E7D32), 'Green'),
  oxblood(Color(0xFF4B0102), 'Oxblood (brand)');

  const CmsAccent(this.color, this.label);
  final Color color;
  final String label;
}

class ThemePrefs {
  const ThemePrefs({required this.themeMode, required this.accent});
  final ThemeMode themeMode;
  final CmsAccent accent;

  ThemePrefs copyWith({ThemeMode? themeMode, CmsAccent? accent}) =>
      ThemePrefs(themeMode: themeMode ?? this.themeMode, accent: accent ?? this.accent);
}

class ThemePrefsController extends AsyncNotifier<ThemePrefs> {
  @override
  Future<ThemePrefs> build() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_themeModeKey);
    final accentName = prefs.getString(_seedColorKey);
    return ThemePrefs(
      themeMode: modeIndex != null && modeIndex < ThemeMode.values.length
          ? ThemeMode.values[modeIndex]
          : ThemeMode.system,
      accent: CmsAccent.values.firstWhere(
        (a) => a.name == accentName,
        orElse: () => CmsAccent.slate,
      ),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(themeMode: mode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }

  Future<void> setAccent(CmsAccent accent) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(accent: accent));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seedColorKey, accent.name);
  }
}

final themePrefsProvider = AsyncNotifierProvider<ThemePrefsController, ThemePrefs>(
  ThemePrefsController.new,
);
