import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/state/media_prefetch.dart';

PeopleRegistry _people() => PeopleRegistry.fromJson(
    jsonDecode(File('../../content/people.json').readAsStringSync())
        as Map<String, dynamic>);

Era _loadEra(String slug) => Era.fromJson(
    jsonDecode(File('../../content/eras/$slug.json').readAsStringSync())
        as Map<String, dynamic>,
    _people());

Period _loadPeriod(String id) {
  final registry = PeriodRegistry.fromJson(
      jsonDecode(File('../../content/periods.json').readAsStringSync())
          as Map<String, dynamic>);
  return registry[id]!;
}

void main() {
  // Real content fixtures: Hồng Bàng (2 eras, has scene layers, characters,
  // events with hero images) and Nhà Triệu (1 era) give two dynasties with
  // enough real art references to exercise ordering and dedupe.
  final hongBangVanLang = _loadEra('hong-bang-van-lang');
  final auLac = _loadEra('au-lac');
  final nhaTrieu = _loadEra('nha-trieu');
  final dynasties = <Dynasty>[
    Dynasty(
        period: _loadPeriod('hong-bang'),
        eras: <Era>[hongBangVanLang, auLac]),
    Dynasty(period: _loadPeriod('nha-trieu'), eras: <Era>[nhaTrieu]),
  ];

  group('homeMediaFor', () {
    test('starts with the period cover, then each era\'s scene layers in order',
        () {
      final paths = homeMediaFor(dynasties[0]);
      final period = dynasties[0].period;
      expect(paths.first, period.cover!.flagship ?? period.cover!.reduced);

      // Every scene-layer image path from both eras must appear, and paths
      // from the first era must all precede the second era's.
      final firstEraPaths = <String>{
        for (final l in hongBangVanLang.sceneLayers) ...[
          if (l.flagship != null) l.flagship!,
          if (l.reduced != null) l.reduced!,
        ],
      };
      final secondEraPaths = <String>{
        for (final l in auLac.sceneLayers) ...[
          if (l.flagship != null) l.flagship!,
          if (l.reduced != null) l.reduced!,
        ],
      };
      expect(firstEraPaths, isNotEmpty);
      final lastFirstEraIndex =
          firstEraPaths.map(paths.indexOf).reduce((a, b) => a > b ? a : b);
      final firstSecondEraIndex = secondEraPaths.isEmpty
          ? paths.length
          : secondEraPaths.map(paths.indexOf).reduce((a, b) => a < b ? a : b);
      expect(lastFirstEraIndex, lessThan(firstSecondEraIndex));
    });

    test('never repeats a path', () {
      final paths = homeMediaFor(dynasties[0]);
      expect(paths.toSet().length, paths.length);
    });

    test('never includes an animated cover video path', () {
      final paths = homeMediaFor(dynasties[0]).toSet();
      for (final era in dynasties[0].eras) {
        for (final l in era.sceneLayers) {
          if (l.video != null) expect(paths.contains(l.video), isFalse);
        }
      }
    });
  });

  group('firstPageMediaFor', () {
    test('is the period cover plus only the first era\'s scene layers', () {
      final paths = firstPageMediaFor(dynasties[0]).toSet();
      final secondEraOnlyPaths = <String>{
        for (final l in auLac.sceneLayers)
          if (l.flagship != null &&
              !hongBangVanLang.sceneLayers.any((f) => f.flagship == l.flagship))
            l.flagship!,
      };
      for (final p in secondEraOnlyPaths) {
        expect(paths.contains(p), isFalse);
      }
    });

    test('is a subset of homeMediaFor for the same dynasty', () {
      final full = homeMediaFor(dynasties[0]).toSet();
      final first = firstPageMediaFor(dynasties[0]);
      for (final p in first) {
        expect(full.contains(p), isTrue);
      }
    });
  });

  group('eraHubMediaFor', () {
    test('includes every event hero and character avatar/fullBody/portrait',
        () {
      final paths = eraHubMediaFor(hongBangVanLang).toSet();
      for (final e in hongBangVanLang.events) {
        if (e.hero?.flagship != null) expect(paths, contains(e.hero!.flagship));
      }
      for (final c in hongBangVanLang.characters) {
        if (c.avatar?.flagship != null) {
          expect(paths, contains(c.avatar!.flagship));
        }
        if (c.fullBody?.flagship != null) {
          expect(paths, contains(c.fullBody!.flagship));
        }
        if (c.portrait?.flagship != null) {
          expect(paths, contains(c.portrait!.flagship));
        }
      }
    });

    test('orders scene-layer videos last', () {
      final paths = eraHubMediaFor(hongBangVanLang);
      final videoPaths = <String>{
        for (final l in hongBangVanLang.sceneLayers)
          if (l.video != null) l.video!,
      };
      if (videoPaths.isNotEmpty) {
        final firstVideoIndex =
            videoPaths.map(paths.indexOf).reduce((a, b) => a < b ? a : b);
        expect(firstVideoIndex, paths.length - videoPaths.length);
      }
    });
  });

  group('prefetchWindow', () {
    test('starts with the current dynasty\'s own media', () {
      final window = prefetchWindow(dynasties, 0);
      final home0 = homeMediaFor(dynasties[0]);
      expect(window.take(home0.length).toList(), home0);
    });

    test('includes the next dynasties ahead and the previous one, deduped',
        () {
      final window = prefetchWindow(dynasties, 1).toSet();
      final expected = <String>{
        ...homeMediaFor(dynasties[1]),
        ...homeMediaFor(dynasties[0]),
      };
      expect(window, expected);
    });

    test('clamps and never throws at the list bounds', () {
      expect(() => prefetchWindow(dynasties, -5), returnsNormally);
      expect(() => prefetchWindow(dynasties, 500), returnsNormally);
      expect(() => prefetchWindow(const <Dynasty>[], 0), returnsNormally);
      expect(prefetchWindow(const <Dynasty>[], 0), isEmpty);
    });
  });
}
