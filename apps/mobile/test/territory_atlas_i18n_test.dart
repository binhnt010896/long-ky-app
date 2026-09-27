import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/screens/prototype/territory_atlas_data.dart';
import 'package:viet_su/screens/prototype/territory_map_demo_screen.dart';
import 'package:viet_su/state/providers.dart';
import 'package:viet_su/widgets/territory_map.dart';

void main() {
  group('atlas data (Cycle J)', () {
    test('every snapshot has non-empty Vietnamese and English', () {
      for (final snap in kAtlas) {
        expect(snap.title.vi, isNotEmpty, reason: '${snap.id} title.vi');
        expect(snap.title.resolve(Lang.en), isNotEmpty,
            reason: '${snap.id} title en resolve');
        if (snap.subtitle != null) {
          expect(snap.subtitle!.resolve(Lang.en), isNotEmpty,
              reason: '${snap.id} subtitle en resolve');
        }
        if (snap.boundaryLabel != null) {
          expect(snap.boundaryLabel!.resolve(Lang.en), isNotEmpty,
              reason: '${snap.id} boundaryLabel en resolve');
        }
      }
    });

    test('every region has non-empty Vietnamese and English', () {
      for (final snap in kAtlas) {
        for (final r in snap.regions) {
          expect(r.name.vi, isNotEmpty, reason: '${snap.id}/${r.id} name.vi');
          expect(r.name.resolve(Lang.en), isNotEmpty,
              reason: '${snap.id}/${r.id} name en resolve');
          if (r.subtitle != null) {
            expect(r.subtitle!.resolve(Lang.en), isNotEmpty,
                reason: '${snap.id}/${r.id} subtitle en resolve');
          }
        }
      }
    });

    test('foreign dynasties translate off the Vietnamese phonetic name', () {
      // Spot-check a few well-known cases from decision J2 rather than every
      // row (the full VI->EN table lives in tool/geo/atlas_i18n.py).
      final china = kAtlas
          .expand((s) => s.regions)
          .firstWhere((r) => r.name.vi == 'Nhà Thanh');
      expect(china.name.resolve(Lang.en), 'The Qing Dynasty');

      final vietnameseState = kAtlas
          .expand((s) => s.regions)
          .firstWhere((r) => r.name.vi == 'Đại Việt');
      // Vietnamese polity names stay Vietnamese in English too.
      expect(vietnameseState.name.resolve(Lang.en), 'Đại Việt');
    });
  });

  group('atlas screen (Cycle J)', () {
    Future<void> pump(WidgetTester tester, Lang lang) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[langProvider.overrideWith((ref) => lang)],
          child: const MaterialApp(home: TerritoryMapDemoScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('header reads Vietnamese by default', (tester) async {
      await pump(tester, Lang.vi);
      expect(find.text('BẢN ĐỒ LÃNH THỔ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('header reads English when the toggle is set', (tester) async {
      await pump(tester, Lang.en);
      expect(find.text('TERRITORY ATLAS'), findsOneWidget);
      expect(find.text('BẢN ĐỒ LÃNH THỔ'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Hoàng Sa / Trường Sa keep their Vietnamese names in English',
        (tester) async {
      await pump(tester, Lang.en);
      // The island group labels are canvas-painted (not Text widgets, see
      // territory_map.dart's `_text` helper), so assert on the data passed
      // into TerritoryMap rather than the rendered text.
      final map = tester.widget<TerritoryMap>(find.byType(TerritoryMap));
      final names = map.islands.map((i) => i.name).toList();
      expect(names, containsAll(<String>['Hoàng Sa', 'Trường Sa']));
      // Never the disputed English exonyms.
      expect(names.any((n) => n.contains('Paracel')), isFalse);
      expect(names.any((n) => n.contains('Spratly')), isFalse);
      expect(map.islands.every((i) => i.subtitle == 'Archipelago of Vietnam'),
          isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
