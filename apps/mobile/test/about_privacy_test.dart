import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:viet_su/screens/sanh/about_screen.dart';
import 'package:viet_su/state/content_sync.dart';
import 'package:viet_su/state/providers.dart';
import 'package:viet_su/telemetry/telemetry_settings.dart';

class _Store implements TelemetrySettingsStore {
  @override
  Future<bool> load() async => true;
  @override
  Future<void> setEnabled(bool enabled) async {}
}

Future<List<Uri>> _pump(WidgetTester tester,
    {Lang lang = Lang.vi, bool opens = true}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <Uri>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      langProvider.overrideWith((ref) => lang),
      activeContentVersionProvider.overrideWith((ref) => 0),
      telemetrySettingsStoreProvider.overrideWithValue(_Store()),
      urlOpenerProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return opens;
      }),
    ],
    child: MaterialApp(theme: VSTheme.build(), home: const AboutScreen()),
  ));
  await tester.pump();
  return opened;
}

void main() {
  testWidgets('the About page links the privacy policy and opens it', (tester) async {
    final opened = await _pump(tester);
    final link = find.byKey(const Key('privacy-policy-link'));
    await tester.scrollUntilVisible(link, 300);
    expect(find.text('Chính sách quyền riêng tư'), findsOneWidget);
    await tester.tap(link);
    await tester.pump();
    expect(opened, [Uri.parse('https://binh-nt.dev/long-ky/privacy')]);
  });

  testWidgets('English label', (tester) async {
    await _pump(tester, lang: Lang.en);
    await tester.scrollUntilVisible(find.byKey(const Key('privacy-policy-link')), 300);
    expect(find.text('Privacy policy'), findsOneWidget);
  });

  testWidgets('if the browser cannot open, say where the page is', (tester) async {
    await _pump(tester, opens: false);
    final link = find.byKey(const Key('privacy-policy-link'));
    await tester.scrollUntilVisible(link, 300);
    await tester.tap(link);
    await tester.pump();
    expect(find.textContaining('binh-nt.dev/long-ky/privacy'), findsOneWidget);
  });

  test('the version shown on the About page matches pubspec', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final name = line.split(':')[1].trim().split('+').first;
    expect(kAppVersion, name);
  });

  test('Android can open https links (url_launcher needs the query)', () {
    final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(m, contains('android.intent.action.VIEW'));
    expect(m, contains('android:scheme="https"'));
  });
}
