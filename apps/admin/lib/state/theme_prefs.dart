import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'cms.themeMode';
const _seedColorKey = 'cms.seedColor';
const _defaultPrefs = ThemePrefs(themeMode: ThemeMode.system, accent: CmsAccent.slate);

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
  SharedPreferences? _prefs;

  Future<SharedPreferences?> _loadPrefs() async {
    if (_prefs != null) return _prefs;
    try {
      return _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // Some browser privacy settings (e.g. strict storage partitioning)
      // can make this throw or hang — the picker still has to work for the
      // rest of the session even if nothing persists across a reload.
      return null;
    }
  }

  @override
  Future<ThemePrefs> build() async {
    final prefs = await _loadPrefs();
    if (prefs == null) return _defaultPrefs;
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

  /// Applies [update] to the in-memory state immediately regardless of
  /// whether [build] ever resolved — a click in the Appearance dialog must
  /// always do something, even if persistence itself later fails.
  Future<void> _apply(
    ThemePrefs Function(ThemePrefs) update,
    void Function(SharedPreferences) persist,
  ) async {
    final current = state.valueOrNull ?? _defaultPrefs;
    state = AsyncData(update(current));
    final prefs = await _loadPrefs();
    if (prefs != null) persist(prefs);
  }

  Future<void> setThemeMode(ThemeMode mode) => _apply(
    (p) => p.copyWith(themeMode: mode),
    (prefs) => prefs.setInt(_themeModeKey, mode.index),
  );

  Future<void> setAccent(CmsAccent accent) => _apply(
    (p) => p.copyWith(accent: accent),
    (prefs) => prefs.setString(_seedColorKey, accent.name),
  );
}

final themePrefsProvider = AsyncNotifierProvider<ThemePrefsController, ThemePrefs>(
  ThemePrefsController.new,
);
