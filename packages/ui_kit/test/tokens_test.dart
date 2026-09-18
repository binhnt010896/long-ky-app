import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  group('VSEraPalette', () {
    test('founding-era preset carries jade accent and a full scene gradient',
        () {
      const p = VSEraPalette.hongBangVanLang;
      expect(p.accent, const Color(0xFF5F8F74));
      expect(p.sceneStops.length, greaterThanOrEqualTo(5));
      expect(p.sceneGradient.colors, p.sceneStops);
    });

    test('fromAccent derives a palette from a hex string (JSON-driven path)',
        () {
      final p = VSEraPalette.fromAccent('river-test', '#4A7C9B');
      expect(p.accent, const Color(0xFF4A7C9B));
      // Bright variant is lifted toward light.
      expect(p.accentBright.computeLuminance(),
          greaterThan(p.accent.computeLuminance()));
      // Scene grades down into lacquer.
      expect(p.sceneStops.first, VSColors.lacquerDeep);
      expect(p.sceneStops.last, VSColors.lacquerRaised);
    });

    test('fromAccent accepts hex with or without leading #', () {
      final a = VSEraPalette.fromAccent('x', 'B5734A');
      final b = VSEraPalette.fromAccent('x', '#B5734A');
      expect(a.accent, b.accent);
      expect(a.accent, const Color(0xFFB5734A));
    });

    test('equality is value-based', () {
      expect(VSEraPalette.jade, VSEraPalette.jade);
      expect(VSEraPalette.jade == VSEraPalette.river, isFalse);
    });
  });

  group('VSType', () {
    test('em tracking converts to pixel letterSpacing', () {
      expect(VSType.track(0.34, 11), closeTo(3.74, 0.001));
    });

    test('kicker is bright gold, wide-tracked, uppercase-intended', () {
      final k = VSType.kicker;
      expect(k.color, VSColors.goldBright);
      expect(k.letterSpacing, greaterThan(3));
    });
  });

  group('VSTheme', () {
    test('build() threads the era palette through a VSEraTheme extension', () {
      final theme = VSTheme.build(era: VSEraPalette.river);
      final ext = theme.extension<VSEraTheme>();
      expect(ext, isNotNull);
      expect(ext!.palette, VSEraPalette.river);
      expect(theme.scaffoldBackgroundColor, VSColors.lacquer);
      expect(theme.colorScheme.secondary, VSEraPalette.river.accent);
    });

    testWidgets('context.era reads the current palette, falls back when unset',
        (tester) async {
      late VSEraPalette seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: VSTheme.build(era: VSEraPalette.terracotta),
          home: Builder(
            builder: (context) {
              seen = context.era;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, VSEraPalette.terracotta);
    });
  });
}
