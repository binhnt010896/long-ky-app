import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:test/test.dart';

Map<String, dynamic> _json(String rel) =>
    jsonDecode(File('../../content/$rel').readAsStringSync())
        as Map<String, dynamic>;

List<Map<String, dynamic>> _eraJsons() => [
      for (final f in Directory('../../content/eras').listSync().whereType<File>())
        if (f.path.endsWith('.json'))
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
    ];

Map<String, dynamic> _event(String id, {int? order, String kind = 'historical'}) =>
    <String, dynamic>{
      'id': id,
      if (order != null) 'order': order,
      'kind': kind,
      'year': <String, dynamic>{
        'value': 1000,
        'display': <String, dynamic>{'vi': '1000'},
      },
      'title': <String, dynamic>{'vi': 'Tiêu đề $id'},
      'summary': <String, dynamic>{'vi': 'Tóm tắt $id'},
      'citation': <String, dynamic>{
        'work': 'Đại Việt sử ký toàn thư',
      },
    };

void main() {
  group('EventRegistry', () {
    test('parses events without an order and indexes them by id', () {
      final reg = EventRegistry.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'events': [_event('a'), _event('b')],
      });
      expect(reg.events.map((e) => e.id), ['a', 'b']);
      expect(reg['b']?.title.vi, 'Tiêu đề b');
      expect(reg['nope'], isNull);
    });
  });

  group('HistoryEvent.order', () {
    test('an event inlined in an era still needs its own order', () {
      expect(() => HistoryEvent.fromJson(_event('x')),
          throwsA(isA<ContentFormatException>()));
      expect(HistoryEvent.fromJson(_event('x', order: 3)).order, 3);
    });

    test('withOrder changes only the order', () {
      final e = HistoryEvent.fromJson(_event('x', order: 0));
      final moved = e.withOrder(5);
      expect(moved.order, 5);
      expect(moved.withOrder(0), e);
    });
  });

  group('Era.fromJson with event refs', () {
    final people = PeopleRegistry.fromJson(_json('people.json'));
    final registry = EventRegistry.fromJson(_json('events.json'));
    final byId = eventJsonById(_json('events.json'));

    test('a ref takes its list position as its order', () {
      final era = Era.fromJson(_eraJsons().first, people, registry);
      expect(era.events.map((e) => e.order), [
        for (var i = 0; i < era.events.length; i++) i,
      ]);
      final refs = (_eraJsons().first['events'] as List)
          .map((r) => (r as Map)['ref'])
          .toList();
      expect(era.events.map((e) => e.id), refs);
    });

    test('every real era parses the same from refs as from inlined events', () {
      for (final json in _eraJsons()) {
        final fromRefs = Era.fromJson(json, people, registry);
        final inlined = Era.fromJson(inlineEraEvents(json, byId), people);
        expect(fromRefs, inlined, reason: '${json['slug']} differs');
      }
    });

    test('an unknown ref is a located ContentFormatException', () {
      final json = Map<String, dynamic>.of(_eraJsons().first)
        ..['events'] = [
          <String, String>{'ref': 'no-such-event'},
        ];
      expect(
        () => Era.fromJson(json, people, registry),
        throwsA(isA<ContentFormatException>()
            .having((e) => e.message, 'message', contains('no-such-event'))),
      );
    });

    test('with no registry, a ref cannot resolve (packs carry inlined events)', () {
      expect(() => Era.fromJson(_eraJsons().first, people),
          throwsA(isA<ContentFormatException>()));
    });
  });

  group('inlineEraEvents', () {
    final byId = eventJsonById(_json('events.json'));

    test('puts order right before kind, like an authored event', () {
      final out = withOrderKey(_event('x'), 4);
      final keys = out.keys.toList();
      expect(out['order'], 4);
      expect(keys.indexOf('order'), keys.indexOf('kind') - 1);
    });

    test('leaves an era with nothing to inline untouched', () {
      final inlined = inlineEraEvents(_eraJsons().first, byId);
      expect(inlineEraEvents(inlined, byId), same(inlined));
    });

    test('keeps an already-inlined event as it is', () {
      final era = <String, dynamic>{
        'events': [
          _event('own', order: 0),
          <String, dynamic>{'ref': byId.keys.first},
        ],
      };
      final out = inlineEraEvents(era, byId)['events'] as List;
      expect((out[0] as Map)['id'], 'own');
      expect((out[1] as Map)['order'], 1);
    });

    test('an unknown ref names the missing id', () {
      expect(
        () => inlineEraEvents(<String, dynamic>{
              'events': [
                <String, String>{'ref': 'gone'},
              ],
            }, byId),
        throwsA(isA<ContentFormatException>()
            .having((e) => e.message, 'message', contains('gone'))),
      );
    });
  });

  group('eventJsonById', () {
    test('rejects a duplicate id', () {
      expect(
        () => eventJsonById(<String, dynamic>{
          'events': [_event('a'), _event('a')],
        }),
        throwsA(isA<ContentFormatException>()),
      );
    });
  });

  group('standaloneEventIds', () {
    test('an event no era lists is standalone, in registry order', () {
      final eras = <Map<String, dynamic>>[
        {
          'events': [
            <String, String>{'ref': 'a'},
            _event('inline-one', order: 1),
          ],
        },
      ];
      expect(standaloneEventIds(eras, ['a', 'b', 'inline-one', 'c']), ['b', 'c']);
    });

    test('the real content has no standalone events yet', () {
      expect(
        standaloneEventIds(
            _eraJsons(), eventJsonById(_json('events.json')).keys),
        isEmpty,
      );
    });
  });
}
