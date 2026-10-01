import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:viet_su/screens/splash/splash_gate.dart';

Widget _splash({bool reduceMotion = false}) => MaterialApp(
      theme: VSTheme.build(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const Material(
          child: SplashScreenView(contentIn: true, showProgress: false, progress: 0),
        ),
      ),
    );

void main() {
  test('the splash art is a real, small, bundled file', () {
    final f = File(kSplashArt);
    expect(f.existsSync(), isTrue);
    expect(f.lengthSync(), lessThan(600 * 1024)); // it ships inside the app
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/brand/'));
  });

  for (final size in const [Size(390, 844), Size(360, 640), Size(412, 915)]) {
    testWidgets('renders the art, seal and wordmark at ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_splash());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('splash-art')), findsOneWidget);
      expect(find.byKey(const Key('splash-wordmark')), findsOneWidget);
      expect(find.text('NGHÌN NĂM SỬ VIỆT'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // The wordmark is Playfair Display Italic, as chosen.
      final t = tester.widget<Text>(find.byKey(const Key('splash-wordmark')));
      expect(t.style!.fontStyle, FontStyle.italic);
      expect(t.style!.fontFamily, endsWith(VSType.familyDisplay));
    });
  }

  testWidgets('the art drifts slowly, and stands still with reduced motion',
      (tester) async {
    double scale() => tester
        .widget<Transform>(find.descendant(
            of: find.byType(SplashScreenView), matching: find.byType(Transform)).first)
        .transform
        .getMaxScaleOnAxis();

    await tester.pumpWidget(_splash());
    await tester.pump();
    final start = scale();
    await tester.pump(const Duration(seconds: 5));
    expect(scale(), greaterThan(start));
    expect(scale(), lessThanOrEqualTo(1.0301));

    await tester.pumpWidget(const SizedBox()); // a fresh splash, not the same State
    await tester.pumpWidget(_splash(reduceMotion: true));
    await tester.pump(const Duration(seconds: 5));
    expect(scale(), 1.0);
  });

  test('the launch window is lacquer-dark, never white', () {
    for (final f in const [
      'android/app/src/main/res/drawable/launch_background.xml',
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ]) {
      final x = File(f).readAsStringSync();
      expect(x, contains('@color/launch_background'), reason: f);
      expect(x, isNot(contains('white')), reason: f);
      expect(x, isNot(contains('colorBackground')), reason: f);
    }
    expect(File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
        contains('#07100F'));
  });
}
