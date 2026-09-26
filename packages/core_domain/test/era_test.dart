import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

/// Path to the real content file, relative to this package's root (the cwd when
/// `dart test` runs). Parsing it here doubles as a content smoke-test.
File get _hongBangFile =>
    File('../../content/eras/hong-bang-van-lang.json');

File get _peopleFile => File('../../content/people.json');

PeopleRegistry _loadPeople() => PeopleRegistry.fromJson(
    jsonDecode(_peopleFile.readAsStringSync()) as Map<String, dynamic>);

void main() {
  group('Era.fromJson (real Hồng Bàng content)', () {
    late Era era;

    setUpAll(() {
      final people = _loadPeople();
      final json = jsonDecode(_hongBangFile.readAsStringSync())
          as Map<String, dynamic>;
      era = Era.fromJson(json, people);
    });

    test('parses era-level fields with diacritics intact', () {
      expect(era.slug, 'hong-bang-van-lang');
      expect(era.order, 0);
      expect(era.title.vi, 'Hồng Bàng & Văn Lang');
      expect(era.kicker.vi, 'Kỷ nguyên khởi thủy');
      expect(era.kicker.resolve(Lang.en), 'The founding era');
      expect(era.yearRange.startYear, -2879);
      expect(era.palette.accent, '#5f8f74');
      expect(era.primarySource.work, 'Đại Việt sử ký toàn thư');
    });

    test('has the seven founding events, sorted by order', () {
      expect(era.events, hasLength(7));
      expect(
        era.events.map((e) => e.order),
        [0, 1, 2, 3, 4, 5, 6],
      );
      expect(era.events.first.title.vi, 'Kinh Dương Vương lập nước');
      expect(era.events.last.title.vi, 'Thục Phán thay nhà Hùng');
    });

    test('the hundred-eggs beat is a legend with no numeric year', () {
      final auCo = era.events[1];
      expect(auCo.kind, EventKind.legend);
      expect(auCo.year.isDated, isFalse);
      expect(auCo.year.value, isNull);
      expect(auCo.summary.vi, contains('trăm trứng'));
    });

    test('every event carries a visible citation', () {
      for (final e in era.events) {
        expect(e.citation.work, isNotEmpty, reason: '${e.id} missing work');
        expect(e.citation.section?.vi, isNotNull,
            reason: '${e.id} missing section');
      }
    });

    test('event 0 has body, pull-quote and dated (approximate) year', () {
      final e = era.events.first;
      expect(e.year.value, -2879);
      expect(e.year.approximate, isTrue);
      expect(e.body!.vi, contains('Xích Quỷ'));
      expect(e.pullQuote!.text.vi, 'Ta là giống rồng, nàng là giống tiên…');
      expect(e.pullQuote!.attribution!.vi, 'Lạc Long Quân');
    });

    test('scene layers are ordered back → front for the parallax slots', () {
      expect(era.sceneLayers, isNotEmpty);
      final depths = era.sceneLayers.map((l) => l.depth ?? 0).toList();
      final sorted = [...depths]..sort();
      expect(depths, sorted, reason: 'layers should be authored far → near');
      // Real sơn mài art is wired: the sky/ridge layers carry assets; only the
      // procedural particle layer stays asset-less.
      final sky = era.sceneLayers.firstWhere((l) => l.role == AssetRole.sky);
      expect(sky.isPlaceholder, isFalse);
      expect(sky.flagship, isNotNull);
      final particles =
          era.sceneLayers.where((l) => l.role == AssetRole.particles);
      expect(particles.every((l) => l.isPlaceholder), isTrue,
          reason: 'particles are drawn procedurally, not from an asset');
    });

    test('character roster resolves per event via figureIds', () {
      // Nine now: the seven originals plus Thánh Gióng and Lang Liêu.
      expect(era.characters, hasLength(9));
      final figures = era.charactersFor(era.events.first);
      expect(figures.map((c) => c.name.vi),
          <String>['Kinh Dương Vương', 'Lạc Long Quân']);
      expect(figures.first.epithet!.resolve(Lang.en), 'Progenitor king');
      // Cycle I retired the legacy 3-part sheet for this era's figures in
      // favor of dedicated avatar/fullBody art (see [[character-avatar-fullbody]]).
      expect(figures.first.avatar?.flagship, isNotNull);
      expect(figures.first.fullBody?.flagship, isNotNull);
      // Legend event with two spirits — Sơn Tinh–Thủy Tinh now sits at index 5.
      final st = era.charactersFor(era.events[5]);
      expect(st.map((c) => c.name.vi), <String>['Sơn Tinh', 'Thủy Tinh']);
    });

    test('events carry fuller details and resolve related events', () {
      final first = era.events.first;
      expect(first.details, isNotNull);
      expect(first.details!.vi, contains('Xích Quỷ'));
      final related = era.relatedEventsFor(first);
      expect(related.map((e) => e.id), <String>['lac-long-quan-au-co']);
      // Vua Hùng links to three events; self is never included.
      final vuaHung = era.events[2];
      final vhRelated = era.relatedEventsFor(vuaHung);
      expect(vhRelated, hasLength(3));
      expect(vhRelated.every((e) => e.id != vuaHung.id), isTrue);
    });

    test('figures resolve by id, carry bios, and map to their events', () {
      final llq = era.figureById('lac-long-quan');
      expect(llq, isNotNull);
      expect(llq!.bio!.vi, contains('Sùng Lãm'));
      expect(llq.bio!.resolve(Lang.en), contains('water realm'));
      // Lạc Long Quân appears in the first two events.
      final appears = era.eventsWithFigure('lac-long-quan');
      expect(
        appears.map((e) => e.id),
        containsAll(<String>['kinh-duong-vuong-lap-nuoc', 'lac-long-quan-au-co']),
      );
      // Unknown id resolves to nothing.
      expect(era.figureById('nobody'), isNull);
      expect(era.eventsWithFigure('nobody'), isEmpty);
    });

    test('English toggle falls back to vi when no en is present', () {
      // event[1] pullQuote has no attribution; title en == vi here.
      final e = era.events[1];
      expect(e.title.resolve(Lang.en), e.title.vi);
    });
  });

  group('Shared people across eras', () {
    late PeopleRegistry people;
    setUpAll(() => people = _loadPeople());

    Era loadEra(String slug) => Era.fromJson(
          jsonDecode(File('../../content/eras/$slug.json').readAsStringSync())
              as Map<String, dynamic>,
          people,
        );

    test('Triệu Đà is one person, reframed per era, with one canonical image', () {
      final inAuLac = loadEra('au-lac').figureById('trieu-da')!;
      final namViet = loadEra('nha-trieu');
      final inNamViet = namViet.figureById('trieu-da')!;

      // One person id, one canonical avatar — never two people.
      expect(inAuLac.id, 'trieu-da');
      expect(inNamViet.id, 'trieu-da');
      expect(inAuLac.avatar?.flagship, isNotNull);
      expect(inAuLac.avatar, inNamViet.avatar);

      // Reframed for its era by the Nam Việt override.
      expect(inAuLac.name.vi, 'Triệu Đà');
      expect(inNamViet.name.vi, 'Triệu Vũ Đế');
      expect(inNamViet.epithet!.vi, 'Vua dựng Nam Việt');

      // The canonical people.json entry keeps the base name.
      expect(people['trieu-da']!.name.vi, 'Triệu Đà');
      expect(namViet.eventsWithFigure('trieu-da'), isNotEmpty);
    });
  });

  group('LocalizedText', () {
    test('resolve never drops diacritics on en fallback', () {
      const t = LocalizedText(vi: 'Đại Việt');
      expect(t.resolve(Lang.en), 'Đại Việt');
      expect(t.hasEnglish, isFalse);
    });
  });

  group('malformed input', () {
    test('missing required field throws a located ContentFormatException', () {
      expect(
        () => Era.fromJson(
            <String, dynamic>{'schemaVersion': 1}, PeopleRegistry.empty),
        throwsA(isA<ContentFormatException>()),
      );
    });
  });
}
