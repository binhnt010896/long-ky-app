import 'package:admin/state/theme_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('setThemeMode updates state immediately, even before build() resolves', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Deliberately not awaiting themePrefsProvider.future first — this is
    // the exact race a fast click right after page load hits. The old
    // implementation's setters no-op'd whenever `state.valueOrNull` was
    // still null (build() pending, or failed outright, e.g. under strict
    // browser storage partitioning), which read as "I click but nothing
    // happens".
    final notifier = container.read(themePrefsProvider.notifier);
    await notifier.setThemeMode(ThemeMode.dark);

    final value = container.read(themePrefsProvider).requireValue;
    expect(value.themeMode, ThemeMode.dark);
  });

  test('setAccent updates state immediately and persists it', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themePrefsProvider.notifier).setAccent(CmsAccent.teal);
    expect(container.read(themePrefsProvider).requireValue.accent, CmsAccent.teal);

    // A fresh controller picks the persisted choice back up.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cms.seedColor'), 'teal');
  });

  test('an unresolvable accent name falls back to slate, not a crash', () async {
    SharedPreferences.setMockInitialValues({'cms.seedColor': 'not-a-real-accent'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final value = await container.read(themePrefsProvider.future);
    expect(value.accent, CmsAccent.slate);
  });
}
