import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

Map<String, dynamic> _era(String slug, int order,
        {List<String> roster = const [], List<Map<String, dynamic>> events = const []}) =>
    {
      'slug': slug,
      'order': order,
      'title': {'vi': 'Thời $slug', 'en': slug},
      'characters': [for (final r in roster) {'ref': r}],
      'events': events,
    };

Map<String, dynamic> _person(String id, String vi) => {
      'id': id,
      'name': {'vi': vi, 'en': vi},
    };

void main() {
  group('normalizeName', () {
    test('drops street prefixes only when asked, folds case and dashes', () {
      expect(normalizeName('Đường Lê Lợi', stripStreetPrefix: true), 'lê lợi');
      expect(normalizeName('Đại lộ Võ Văn Kiệt', stripStreetPrefix: true),
          'võ văn kiệt');
      expect(normalizeName('Đường Lê Lợi'), 'đường lê lợi');
      expect(normalizeName('Xô Viết Nghệ–Tĩnh'), 'xô viết nghệ tĩnh');
    });

    test('folds the look-alike Ð (U+00D0) to Đ and normalizes to NFC', () {
      // OSM's HCMC `Ðồng Khởi` uses the Icelandic Eth.
      expect(normalizeName('\u00D0ồng Khởi'), normalizeName('Đồng Khởi'));
      expect(normalizeName('Tôn \u00D0ức Thắng'), 'tôn đức thắng');
      // Decomposed "ồ" (o + U+0302 + U+0300) equals the precomposed form.
      expect(normalizeName('Đo\u0302\u0300ng Khởi'), normalizeName('Đồng Khởi'));
      expect(canonicalSpelling('\u00D0ồng Khởi'), 'Đồng Khởi');
      expect(streetSlug('\u00D0ồng Khởi'), 'dong-khoi');
    });

    test('personNameVariants splits on · and drops titles', () {
      expect(personNameVariants('Nguyễn Huệ · Quang Trung'),
          ['nguyễn huệ', 'quang trung']);
      expect(personNameVariants('Đại tướng Võ Nguyên Giáp'), ['võ nguyên giáp']);
    });

    test('streetSlug ascii-folds', () {
      expect(streetSlug('Đường Lê Lợi'), 'le-loi');
      expect(streetSlug('Đồng Khởi'), 'dong-khoi');
      expect(streetSlug('Xô Viết Nghệ Tĩnh'), 'xo-viet-nghe-tinh');
    });
  });

  group('StreetMatcher', () {
    final people = [
      _person('le-loi', 'Lê Lợi'),
      _person('hai-ba-trung-a', 'Hai Bà Trưng'),
      _person('quang-trung', 'Nguyễn Huệ · Quang Trung'),
      _person('orphan', 'Không Ai'),
    ];
    final eras = [
      _era('hau-le', 2, roster: ['le-loi']),
      _era('tay-son', 3, roster: ['quang-trung', 'le-loi']),
      _era('bach-dang', 1, roster: ['hai-ba-trung-a'], events: [
        {'id': 'bach-dang-938', 'title': {'vi': 'Bạch Đằng'}},
      ]),
    ];
    final matcher = StreetMatcher.fromContent(
      people: people,
      eras: eras,
      aliases: [
        {
          'street': 'Quang Trung',
          'targets': [
            {'type': 'person', 'id': 'quang-trung'}
          ],
        },
      ],
    );

    test('home era is the earliest era by order that lists the person', () {
      final s = matcher.suggest(['Lê Lợi']).single;
      expect(s.targets.single.era, 'hau-le');
    });

    test('exact matches auto-approve; people on no roster never match', () {
      final out = matcher.suggest(['Đường Lê Lợi', 'Không Ai']);
      expect(out.map((s) => s.id), ['le-loi']);
      expect(out.single.status, StreetStatus.approved);
      expect(out.single.reason, 'exact');
    });

    test('alias matches wait for review', () {
      final s = matcher.suggest(['Quang Trung']).single;
      expect(s.status, StreetStatus.suggested);
      expect(s.targets.single.id, 'quang-trung');
      expect(s.targets.single.era, 'tay-son');
    });

    test('event titles match exactly; era titles too', () {
      final s = matcher.suggest(['Bạch Đằng', 'Thời tay-son']);
      expect(s.map((x) => x.id).toSet(), {'bach-dang', 'thoi-tay-son'});
    });

    test('a name with several targets is multi and not auto-approved', () {
      final m = StreetMatcher.fromContent(people: [
        _person('trung-a', 'Hai Bà Trưng'),
      ], eras: [
        _era('e', 0, roster: ['trung-a']),
      ], aliases: [
        {
          'street': 'Hai Bà Trưng',
          'targets': [
            {'type': 'era', 'id': 'e'}
          ],
        },
      ]);
      final s = m.suggest(['Hai Bà Trưng']).single;
      expect(s.reason, 'multi');
      expect(s.targets, hasLength(2));
      expect(s.status, StreetStatus.suggested);
    });

    test('an Eth-spelled OSM name matches and is stored with Đ', () {
      final m = StreetMatcher.fromContent(people: [], eras: [
        _era('e', 0, events: [
          {'id': 'dong-khoi', 'title': {'vi': 'Đồng Khởi'}},
        ]),
      ]);
      final s = m.suggest(['\u00D0ồng Khởi']).single;
      expect(s.id, 'dong-khoi');
      expect(s.name, 'Đồng Khởi');
    });

    test('duplicate OSM names collapse to one street', () {
      expect(matcher.suggest(['Lê Lợi', 'Đường Lê Lợi', 'lê lợi']), hasLength(1));
    });

    test('merge never un-approves and never overwrites hand edits', () {
      const t = StreetTarget(type: StreetTargetType.person, id: 'x', era: 'e');
      final existing = [
        const MappedStreet(
            id: 'le-loi', name: 'Lê Lợi', targets: [t], status: StreetStatus.approved),
      ];
      final fresh = [
        const MappedStreet(
            id: 'le-loi',
            name: 'Lê Lợi',
            targets: [
              StreetTarget(type: StreetTargetType.era, id: 'e', era: 'e')
            ],
            status: StreetStatus.suggested),
        const MappedStreet(
            id: 'a-new',
            name: 'A',
            targets: [t],
            status: StreetStatus.suggested),
      ];
      final merged = StreetMatcher.merge(existing, fresh);
      expect(merged.map((s) => s.id), ['a-new', 'le-loi']);
      final ll = merged.firstWhere((s) => s.id == 'le-loi');
      expect(ll.status, StreetStatus.approved);
      expect(ll.targets.single, t);
    });
  });

  group('geometry', () {
    test('simplifyLine drops collinear points but keeps a real corner', () {
      final line = [
        for (var i = 0; i <= 10; i++) GeoPt(106.0 + i * 0.0001, 10.0),
      ];
      expect(simplifyLine(line, 5), [line.first, line.last]);
      final bent = [...line.take(6), const GeoPt(106.0005, 10.002)];
      expect(simplifyLine(bent, 5).length, greaterThan(2));
    });

    test('chainSegments joins end-to-end, reversing when needed', () {
      const a = GeoPt(0, 0), b = GeoPt(1, 0), c = GeoPt(2, 0), d = GeoPt(3, 0);
      final out = chainSegments([
        [a, b],
        [d, c],
        [b, c],
        [const GeoPt(9, 9), const GeoPt(9, 10)],
      ]);
      expect(out, hasLength(2));
      expect(out.first, [a, b, c, d]);
    });

    test('buildStreetLines rounds to 5 decimals', () {
      final out = buildStreetLines([
        [const GeoPt(106.123456789, 10.987654321), const GeoPt(106.2, 10.9)],
      ]);
      expect(out.single.first, const GeoPt(106.12346, 10.98765));
    });

    test('hitTestStreet: nearest within tolerance, null outside', () {
      final lines = {
        'a': [
          [const GeoPt(0, 0), const GeoPt(100, 0)]
        ],
        'b': [
          [const GeoPt(0, 30), const GeoPt(100, 30)]
        ],
      };
      expect(hitTestStreet(const GeoPt(50, 5), lines), 'a');
      expect(hitTestStreet(const GeoPt(50, 20), lines), 'b');
      expect(hitTestStreet(const GeoPt(50, 100), lines), isNull);
      expect(hitTestStreet(const GeoPt(50, 26), lines, toleranceDp: 2), isNull);
    });
  });

  group('StreetMapValidator', () {
    final eras = [
      _era('e1', 0, roster: ['p1'], events: [
        {'id': 'ev1'}
      ]),
    ];
    String file(List<Map<String, dynamic>> streets) => jsonEncode({
          'schemaVersion': 1,
          'city': 'hcm',
          'osmSnapshot': '2026-09-29',
          'streets': streets,
        });
    Map<String, dynamic> street(String id, List<Map<String, dynamic>> t,
            [String status = 'approved']) =>
        {'id': id, 'name': id, 'targets': t, 'status': status};

    List<String> run(List<Map<String, dynamic>> s,
            {Set<String>? geo, Set<String> standalone = const {}}) =>
        StreetMapValidator.validate(
            streetsJson: file(s),
            peopleIds: {'p1'},
            eras: eras,
            geometryStreetIds: geo,
            standaloneEventIds: standalone);

    test('an event with no era is valid only if it is a standalone event', () {
      final targets = [
        {'type': 'event', 'id': 'alone', 'era': ''}
      ];
      expect(run([street('a', targets)], standalone: {'alone'}), isEmpty);
      expect(run([street('a', targets)]).join('\n'),
          contains('has no era and is not a standalone event'));
    });

    test('a good file passes', () {
      expect(
          run([
            street('a', [
              {'type': 'person', 'id': 'p1', 'era': 'e1'},
              {'type': 'event', 'id': 'ev1', 'era': 'e1'},
              {'type': 'era', 'id': 'e1'},
            ])
          ], geo: {'a'}),
          isEmpty);
    });

    test('flags duplicate ids, dangling targets and missing geometry', () {
      final p = run([
        street('a', [
          {'type': 'person', 'id': 'ghost', 'era': 'e1'}
        ]),
        street('a', [
          {'type': 'event', 'id': 'nope', 'era': 'e1'}
        ]),
        street('b', [
          {'type': 'person', 'id': 'p1', 'era': 'zzz'}
        ]),
        street('c', [
          {'type': 'era', 'id': 'e1'}
        ]),
      ], geo: {'a', 'b'});
      expect(p.join('\n'), allOf(contains('not unique'), contains('unknown person "ghost"'),
          contains('event "nope" not in era'), contains('unknown era "zzz"'),
          contains('street "c"'.replaceFirst('street "c"', 'approved street "c" has no geometry'))));
    });

    test('unapproved streets need no geometry', () {
      expect(
          run([
            street('a', [
              {'type': 'era', 'id': 'e1'}
            ], 'suggested')
          ], geo: {}),
          isEmpty);
    });
  });

  test('real content: the matcher runs and only yields resolvable targets', () {
    final people = (jsonDecode(File('../../content/people.json').readAsStringSync())
        as Map<String, dynamic>)['people'] as List;
    final events = eventJsonById(
        jsonDecode(File('../../content/events.json').readAsStringSync())
            as Map<String, dynamic>);
    final eras = [
      for (final f in Directory('../../content/eras')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json')))
        inlineEraEvents(
            jsonDecode(f.readAsStringSync()) as Map<String, dynamic>, events),
    ];
    final m = StreetMatcher.fromContent(
        people: people.cast<Map<String, dynamic>>(), eras: eras);
    final out = m.suggest(['Lê Lợi', 'Trần Hưng Đạo', 'Đường Không Tồn Tại']);
    expect(out.map((s) => s.id), containsAll(['le-loi', 'tran-hung-dao']));
    final f = StreetMapFile(city: 'hcm', osmSnapshot: 't', streets: out);
    final problems = StreetMapValidator.validate(
      streetsJson: jsonEncode(f.toJson()),
      peopleIds: {for (final p in people) (p as Map)['id'] as String},
      eras: eras,
    );
    expect(problems, isEmpty);
  });
}
