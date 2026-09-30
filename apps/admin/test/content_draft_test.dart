import 'dart:convert';
import 'dart:io';

import 'package:admin/api/api_providers.dart';
import 'package:admin/api/cms_api_client.dart';
import 'package:admin/state/content_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A minimal but internally-consistent content set — just enough for the
/// tree/people/period mutation logic under test, not full schema realism
/// (that's core_domain's own test suite's job).
Map<String, String> _fixtureFiles() => {
  'content/era.schema.json': '{"type":"object"}',
  'content/people.schema.json': '{"type":"object"}',
  'content/period.schema.json': '{"type":"object"}',
  'content/event.schema.json': '{"type":"object"}',
  'content/events.json': jsonEncode({'schemaVersion': 1, 'events': <dynamic>[]}),
  'content/streets/hcm.json': jsonEncode({
    'schemaVersion': 1,
    'city': 'hcm',
    'streets': [
      {
        'id': 'only-e1',
        'name': 'Only E1',
        'status': 'approved',
        'targets': [
          {'type': 'event', 'id': 'e1', 'era': 'era-a'},
        ],
      },
      {
        'id': 'e1-and-person',
        'name': 'E1 and person',
        'status': 'approved',
        'targets': [
          {'type': 'event', 'id': 'e1', 'era': 'era-a'},
          {'type': 'person', 'id': 'person-1', 'era': 'era-a'},
        ],
      },
    ],
  }),
  'content/index.json': jsonEncode({
    'schemaVersion': 1,
    'eras': ['era-a', 'era-b'],
  }),
  'content/people.json': jsonEncode({
    'schemaVersion': 1,
    'people': [
      {
        'id': 'person-1',
        'name': {'vi': 'Người Một'},
      },
    ],
  }),
  'content/periods.json': jsonEncode({
    'schemaVersion': 1,
    'periods': [
      {
        'id': 'period-1',
        'order': 0,
        'title': {'vi': 'Kỳ Một'},
        'kicker': {'vi': 'K1'},
        'yearRange': {
          'display': {'vi': 'x'},
        },
        'accent': '#111111',
      },
      {
        'id': 'period-2',
        'order': 1,
        'title': {'vi': 'Kỳ Hai'},
        'kicker': {'vi': 'K2'},
        'yearRange': {
          'display': {'vi': 'y'},
        },
        'accent': '#222222',
      },
    ],
  }),
  'content/eras/era-a.json': jsonEncode({
    'id': 'era-a',
    'slug': 'era-a',
    'order': 0,
    'period': 'period-1',
    'title': {'vi': 'Era A'},
    'characters': [
      {'ref': 'person-1'},
    ],
    'events': <dynamic>[],
  }),
  'content/eras/era-b.json': jsonEncode({
    'id': 'era-b',
    'slug': 'era-b',
    'order': 1,
    'period': 'period-1',
    'title': {'vi': 'Era B'},
    'characters': <dynamic>[],
    'events': <dynamic>[],
  }),
};

/// A [CmsApiClient] wired to a fake `http.Client` that serves [files] for
/// `GET /content` and records the last `POST /commit` body, so the tests
/// exercise the exact same client code the real app calls, not a shortcut.
CmsApiClient _fakeClient(Map<String, String> files, {Map<String, dynamic>? lastCommit}) {
  // http.Response's String constructor picks an encoding from the
  // Content-Type header — 'application/json' defaults to utf8 even with no
  // explicit charset — which is what lets this mock round-trip Vietnamese
  // diacritics the same way the real Worker's JSON responses do.
  http.Response jsonResponse(Object body) =>
      http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

  final mock = MockClient((request) async {
    if (request.method == 'GET' && request.url.path == '/content') {
      return jsonResponse({'sha': 'sha-0', 'files': files});
    }
    if (request.method == 'POST' && request.url.path == '/commit') {
      final body = jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, dynamic>;
      lastCommit?.addAll(body);
      return jsonResponse({'sha': 'sha-1'});
    }
    throw StateError('Unexpected request in test: ${request.method} ${request.url}');
  });
  return CmsApiClient(baseUrl: 'https://example.test', idTokenProvider: () async => 'token', client: mock);
}

Future<ProviderContainer> _containerWith(Map<String, String> files) async {
  final container = ProviderContainer(
    overrides: [cmsApiClientProvider.overrideWithValue(_fakeClient(files))],
  );
  await container.read(contentDraftProvider.future);
  return container;
}

void main() {
  group('ContentDraft (pure model)', () {
    test('withFile on an existing path shows up in pendingChanges', () {
      final draft = ContentDraft.fromLoad(ContentAtHead('sha', {'a.json': '{}'}));
      final edited = draft.withFile('a.json', '{"x":1}');
      expect(edited.pendingChanges, {'a.json': '{"x":1}'});
    });

    test('withFile on a brand-new path is a create, not an edit', () {
      final draft = ContentDraft.fromLoad(ContentAtHead('sha', {'a.json': '{}'}));
      final added = draft.withFile('b.json', '{"y":2}');
      expect(added.pendingChanges, {'b.json': '{"y":2}'});
    });

    test('deleting a baseline path stages a null; deleting a new path just drops it', () {
      final draft = ContentDraft.fromLoad(ContentAtHead('sha', {'a.json': '{}'}));
      final withNew = draft.withFile('b.json', '{}');
      expect(withNew.withDeletedFile('a.json').pendingChanges, {'a.json': null, 'b.json': '{}'});
      expect(withNew.withDeletedFile('b.json').pendingChanges, isEmpty);
    });

    test('settled() clears the diff and adopts the new sha as baseline', () {
      final draft = ContentDraft.fromLoad(ContentAtHead('sha-0', {'a.json': '{}'}));
      final edited = draft.withFile('a.json', '{"x":1}');
      final settled = edited.settled('sha-1');
      expect(settled.baseSha, 'sha-1');
      expect(settled.isDirty, isFalse);
      expect(settled.baseline['a.json'], '{"x":1}');
    });

    test('re-editing back to the baseline value drops out of pendingChanges', () {
      final draft = ContentDraft.fromLoad(ContentAtHead('sha', {'a.json': '{"x":1}'}));
      final roundTrip = draft.withFile('a.json', '{"x":2}').withFile('a.json', '{"x":1}');
      expect(roundTrip.isDirty, isFalse);
    });
  });

  group('ContentDraftController — people', () {
    test('addPerson appends without disturbing the rest of the file', () async {
      final container = await _containerWith(_fixtureFiles());
      addTearDown(container.dispose);

      container.read(contentDraftProvider.notifier).addPerson({
        'id': 'person-2',
        'name': {'vi': 'Người Hai'},
      });

      final draft = container.read(contentDraftProvider).requireValue;
      expect(draft.people.map((p) => p['id']), ['person-1', 'person-2']);
    });

    test('updatePerson only touches the targeted person', () async {
      final container = await _containerWith(_fixtureFiles());
      addTearDown(container.dispose);

      container.read(contentDraftProvider.notifier).updatePerson('person-1', (p) {
        p['name'] = {'vi': 'Đổi tên'};
        return p;
      });

      final draft = container.read(contentDraftProvider).requireValue;
      final person = draft.people.single;
      expect((person['name'] as Map)['vi'], 'Đổi tên');
      expect(person['id'], 'person-1');
    });

    test('deletePerson refuses when an era still references them', () async {
      final container = await _containerWith(_fixtureFiles());
      addTearDown(container.dispose);

      expect(
        () => container.read(contentDraftProvider.notifier).deletePerson('person-1'),
        throwsA(isA<StateError>()),
      );
      // Nothing was mutated by the failed attempt.
      final draft = container.read(contentDraftProvider).requireValue;
      expect(draft.people, hasLength(1));
    });

    test('deletePerson succeeds once no era references them', () async {
      final container = await _containerWith(_fixtureFiles());
      addTearDown(container.dispose);

      container.read(contentDraftProvider.notifier).deleteEra('era-a');
      container.read(contentDraftProvider.notifier).deletePerson('person-1');

      final draft = container.read(contentDraftProvider).requireValue;
      expect(draft.people, isEmpty);
    });
  });

  group('ContentDraftController — periods', () {
    test('deletePeriod refuses while it still has eras', () async {
      final container = await _containerWith(_fixtureFiles());
      addTearDown(container.dispose);

      expect(
        () => container.read(contentDraftProvider.notifier).deletePeriod('period-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('reorderPeriod renumbers order for every period, not just the moved one', () async {
      final container = await _containerWith(_fixtureFiles());
      addTearDown(container.dispose);

      // period-2 (index 1) moves to index 0.
      container.read(contentDraftProvider.notifier).reorderPeriod('period-2', 0);

      final draft = container.read(contentDraftProvider).requireValue;
      final byId = {for (final p in draft.periods) p['id'] as String: p['order'] as int};
      expect(byId, {'period-2': 0, 'period-1': 1});
    });
  });

  group('ContentDraftController — eras', () {
    test('addEra creates the file and lists it in index.json', () async {
      final container = await _containerWith(_fixtureFiles());
      addTearDown(container.dispose);

      container.read(contentDraftProvider.notifier).addEra({
        'id': 'era-c',
        'slug': 'era-c',
        'period': 'period-2',
        'title': {'vi': 'Era C'},
        'events': <dynamic>[],
      });

      final draft = container.read(contentDraftProvider).requireValue;
      expect(draft.eraFiles.keys, contains('era-c.json'));
      final index = draft.indexDecoded['eras'] as List;
      expect(index, contains('era-c'));
      // Global order is appended after the current max (era-b is 1).
      final era = jsonDecode(draft.eraFiles['era-c.json']!) as Map<String, dynamic>;
      expect(era['order'], 2);
    });

    test('deleteEra removes the file and its index.json entry together', () async {
      final container = await _containerWith(_fixtureFiles());
      addTearDown(container.dispose);

      container.read(contentDraftProvider.notifier).deleteEra('era-b');

      final draft = container.read(contentDraftProvider).requireValue;
      expect(draft.eraFiles.keys, isNot(contains('era-b.json')));
      expect(draft.indexDecoded['eras'], isNot(contains('era-b')));
      // The deletion is staged as a null, not just absent from `files`.
      expect(draft.pendingChanges['content/eras/era-b.json'], isNull);
      expect(draft.pendingChanges.containsKey('content/eras/era-b.json'), isTrue);
    });

    test('moveEraToPeriod only rewrites that era\'s own period field', () async {
      final container = await _containerWith(_fixtureFiles());
      addTearDown(container.dispose);

      container.read(contentDraftProvider.notifier).moveEraToPeriod('era-a', 'period-2');

      final draft = container.read(contentDraftProvider).requireValue;
      final era = jsonDecode(draft.eraFiles['era-a.json']!) as Map<String, dynamic>;
      expect(era['period'], 'period-2');
      // era-b's file was never touched.
      expect(draft.pendingChanges.containsKey('content/eras/era-b.json'), isFalse);
    });

    test('nudgeEraOrder swaps only the two eras involved', () async {
      final container = await _containerWith(_fixtureFiles());
      addTearDown(container.dispose);

      // era-a is order 0, era-b is order 1 — move era-b up.
      container.read(contentDraftProvider.notifier).nudgeEraOrder('era-b', up: true);

      final draft = container.read(contentDraftProvider).requireValue;
      final a = jsonDecode(draft.eraFiles['era-a.json']!) as Map<String, dynamic>;
      final b = jsonDecode(draft.eraFiles['era-b.json']!) as Map<String, dynamic>;
      expect(b['order'], 0);
      expect(a['order'], 1);
      // Exactly these two files changed.
      expect(draft.pendingChanges.keys.toSet(), {
        'content/eras/era-a.json',
        'content/eras/era-b.json',
      });
    });
  });

  group('ContentDraftController — events (registry)', () {
    Map<String, dynamic> eraJson(ProviderContainer c, String slug) =>
        jsonDecode(c.read(contentDraftProvider).requireValue.eraFiles['$slug.json']!)
            as Map<String, dynamic>;
    List<String> eraRefs(ProviderContainer c, String slug) => [
          for (final i in (eraJson(c, slug)['events'] as List)) (i as Map)['ref'] as String,
        ];
    ContentDraft draftOf(ProviderContainer c) => c.read(contentDraftProvider).requireValue;
    Map<String, dynamic> ev(String id, {List<String>? related, List<String>? figures}) => {
          'kind': 'historical',
          'year': {
            'display': {'vi': id},
            'value': 1000,
          },
          'title': {'vi': id},
          'summary': {'vi': 's'},
          'citation': {'work': 'w'},
          if (related != null) 'relatedEventIds': related,
          if (figures != null) 'figureIds': figures,
        };

    Future<(ProviderContainer, ContentDraftController)> start() async {
      final c = await _containerWith(_fixtureFiles());
      addTearDown(c.dispose);
      return (c, c.read(contentDraftProvider.notifier));
    }

    test('addEvent puts the event in the registry and lists a ref in the era', () async {
      final (c, n) = await start();
      n.addEvent('era-a', 'first-event', ev('first-event'));

      final e = draftOf(c).eventById('first-event')!;
      expect(e['slug'], 'first-event');
      expect(e.containsKey('order'), isFalse, reason: 'list position is the order');
      expect(eraRefs(c, 'era-a'), ['first-event']);
      expect(draftOf(c).eraSlugOfEvent('first-event'), 'era-a');
      expect(draftOf(c).standaloneEvents, isEmpty);
    });

    test('addStandaloneEvent is in the registry and in no era', () async {
      final (c, n) = await start();
      n.addStandaloneEvent('alone', ev('alone'));

      expect(draftOf(c).eventById('alone'), isNotNull);
      expect(draftOf(c).eraSlugOfEvent('alone'), isNull);
      expect(draftOf(c).standaloneEvents.map((e) => e['id']), ['alone']);
      expect(eraRefs(c, 'era-a'), isEmpty);
    });

    test('updateEvent only touches the targeted event, never its id or order', () async {
      final (c, n) = await start();
      n.addEvent('era-a', 'e1', ev('e1'));
      n.addEvent('era-a', 'e2', ev('e2'));

      n.updateEvent('e1', (e) => e..['title'] = {'vi': 'Đổi tên'}..['id'] = 'hijack'..['order'] = 9);

      expect((draftOf(c).eventById('e1')!['title'] as Map)['vi'], 'Đổi tên');
      expect(draftOf(c).eventById('hijack'), isNull, reason: 'the id is permanent');
      expect(draftOf(c).eventById('e1')!.containsKey('order'), isFalse);
      expect((draftOf(c).eventById('e2')!['title'] as Map)['vi'], 'e2');
    });

    test('deleteEvent removes it everywhere: registry, era, related links, streets', () async {
      final (c, n) = await start();
      n.addEvent('era-a', 'e1', ev('e1'));
      n.addEvent('era-a', 'e2', ev('e2', related: ['e1']));
      n.addStandaloneEvent('alone', ev('alone', related: ['e1', 'e2']));

      n.deleteEvent('e1');

      final d = draftOf(c);
      expect(d.eventById('e1'), isNull);
      expect(eraRefs(c, 'era-a'), ['e2']);
      expect(d.eventById('e2')!.containsKey('relatedEventIds'), isFalse);
      expect(d.eventById('alone')!['relatedEventIds'], ['e2']);
      final streets = (jsonDecode(d.files['content/streets/hcm.json']!) as Map)['streets'] as List;
      // The street that named only e1 is gone; the one with another target stays.
      expect(streets.map((s) => (s as Map)['id']), ['e1-and-person']);
      expect(((streets.single as Map)['targets'] as List).single['type'], 'person');
    });

    test('referencesTo lists the era, the events relating to it, and the streets', () async {
      final (c, n) = await start();
      n.addEvent('era-a', 'e1', ev('e1'));
      n.addStandaloneEvent('alone', ev('alone', related: ['e1']));

      final refs = draftOf(c).referencesTo('e1');
      expect(refs.eraSlug, 'era-a');
      expect(refs.relatedFrom, ['alone']);
      expect(refs.streets.map((s) => s.streetId), ['only-e1', 'e1-and-person']);
      expect(refs.streets.firstWhere((s) => s.streetId == 'only-e1').losesLastTarget, isTrue);
      expect(refs.streets.firstWhere((s) => s.streetId == 'e1-and-person').losesLastTarget, isFalse);
      expect(n.eventsReferencing('e1'), ['alone']);
      // A standalone event nothing points at has nothing to clean up.
      expect(draftOf(c).referencesTo('alone').isEmpty, isTrue);
      expect(draftOf(c).referencesTo('nothing-points-here').isEmpty, isTrue);
    });

    test('reorderEvent reorders the refs in the era', () async {
      final (c, n) = await start();
      for (final id in ['e1', 'e2', 'e3']) {
        n.addEvent('era-a', id, ev(id));
      }
      n.reorderEvent('era-a', 'e3', 0);
      expect(eraRefs(c, 'era-a'), ['e3', 'e1', 'e2']);
    });

    test('removeEventFromEra keeps the event, as a standalone one', () async {
      final (c, n) = await start();
      n.addEvent('era-a', 'e1', ev('e1'));
      n.addEvent('era-a', 'e2', ev('e2'));

      n.removeEventFromEra('e1');

      expect(eraRefs(c, 'era-a'), ['e2']);
      expect(draftOf(c).eventById('e1'), isNotNull);
      expect(draftOf(c).standaloneEvents.map((e) => e['id']), ['e1']);
    });

    test('an era keeps at least one event: removing or moving the last one throws', () async {
      final (c, n) = await start();
      n.addEvent('era-a', 'only', ev('only'));

      expect(() => n.removeEventFromEra('only'), throwsStateError);
      expect(() => n.moveEventToEra('only', 'era-b'), throwsStateError);
      expect(eraRefs(c, 'era-a'), ['only'], reason: 'a refused change changes nothing');
    });

    test('moveEventToEra takes a standalone event into an era, and adds its figures to the roster', () async {
      final (c, n) = await start();
      n.addStandaloneEvent('alone', ev('alone', figures: ['person-1']));

      n.moveEventToEra('alone', 'era-b');

      expect(eraRefs(c, 'era-b'), ['alone']);
      expect(draftOf(c).standaloneEvents, isEmpty);
      final roster = (eraJson(c, 'era-b')['characters'] as List).cast<Map>().map((p) => p['ref']);
      expect(roster, ['person-1'], reason: 'the figure chip has to resolve in the new era');
    });

    test('moveEventToEra between eras leaves the event in exactly one', () async {
      final (c, n) = await start();
      n.addEvent('era-a', 'e1', ev('e1'));
      n.addEvent('era-a', 'e2', ev('e2'));

      n.moveEventToEra('e1', 'era-b');

      expect(eraRefs(c, 'era-a'), ['e2']);
      expect(eraRefs(c, 'era-b'), ['e1']);
      expect(draftOf(c).eraSlugOfEvent('e1'), 'era-b');
    });

    test('moving an event to the era it is already in changes nothing', () async {
      final (c, n) = await start();
      n.addEvent('era-a', 'e1', ev('e1'));
      final before = draftOf(c).files['content/eras/era-a.json'];
      n.moveEventToEra('e1', 'era-a');
      expect(draftOf(c).files['content/eras/era-a.json'], before);
    });

    test('addEra moves an inline placeholder event into the registry', () async {
      final (c, n) = await start();
      n.addEra({
        'id': 'era-c',
        'slug': 'era-c',
        'period': 'period-2',
        'title': {'vi': 'Era C'},
        'events': [
          {
            'id': 'era-c-event-1',
            'order': 0,
            'kind': 'historical',
            'year': {'display': {'vi': ''}},
            'title': {'vi': 'Sự kiện mới'},
            'summary': {'vi': 'x'},
            'citation': {'work': 'w'},
          },
        ],
      });

      expect(eraRefs(c, 'era-c'), ['era-c-event-1']);
      expect(draftOf(c).eventById('era-c-event-1')!.containsKey('order'), isFalse);
      expect(draftOf(c).eventById('era-c-event-1')!['slug'], 'era-c-event-1');
    });

    test('deleting an era keeps its events, now standalone', () async {
      final (c, n) = await start();
      n.addEvent('era-b', 'kept', ev('kept'));
      n.deleteEra('era-b');
      expect(draftOf(c).eventById('kept'), isNotNull);
      expect(draftOf(c).standaloneEvents.map((e) => e['id']), ['kept']);
    });

    test('deletePerson refuses while a standalone event features them', () async {
      final (c, n) = await start();
      n.ensureInRoster('era-b', 'person-2');
      n.addStandaloneEvent('alone', ev('alone', figures: ['person-2']));
      n.updatePerson('person-1', (p) => p); // no-op: keep the fixture honest
      // person-1 is still on era-a's roster; free it so only the event blocks.
      n.updateEra('era-a', (e) => e..['characters'] = <dynamic>[]);
      n.addStandaloneEvent('alone-2', ev('alone-2', figures: ['person-1']));

      expect(() => n.deletePerson('person-1'), throwsStateError);
    });

    test('ensureInRoster adds a person only if missing', () async {
      final (c, n) = await start();
      n.ensureInRoster('era-a', 'person-1');
      var characters = (eraJson(c, 'era-a')['characters'] as List);
      expect(characters, hasLength(1));

      n.ensureInRoster('era-a', 'person-2');
      characters = (eraJson(c, 'era-a')['characters'] as List);
      expect(characters.cast<Map>().map((p) => p['ref']), ['person-1', 'person-2']);
    });

    test('peopleOnAnyRoster and standaloneEventsFeaturing reflect the draft', () async {
      final (c, n) = await start();
      n.addStandaloneEvent('alone', ev('alone', figures: ['person-1']));
      expect(draftOf(c).peopleOnAnyRoster, {'person-1'});
      expect(draftOf(c).standaloneEventsFeaturing('person-1'), ['alone']);
      expect(draftOf(c).standaloneEventsFeaturing('person-9'), isEmpty);
    });
  });

  // The fixture above is deliberately schema-free. This group runs the same
  // operations over the REAL content and checks the REAL validator after every
  // step: a draft built only through the controller must never trip a rule.
  group('ContentDraftController — events over the real content', () {
    Map<String, String> realFiles() {
      final root = Directory('../../content');
      final out = <String, String>{};
      for (final f in root.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.json')) continue;
        out['content/${f.path.substring(root.path.length + 1)}'] = f.readAsStringSync();
      }
      return out;
    }

    Future<(ProviderContainer, ContentDraftController)> startReal() async {
      final c = await _containerWith(realFiles());
      addTearDown(c.dispose);
      return (c, c.read(contentDraftProvider.notifier));
    }

    void expectValid(ProviderContainer c, String step) {
      final result = c.read(contentDraftProvider).requireValue.validate();
      expect(result.isValid, isTrue, reason: '$step: ${result.issues.join('; ')}');
    }

    Map<String, dynamic> standalone({List<String> figures = const []}) => {
          'kind': 'historical',
          'year': {
            'display': {'vi': '1500'},
            'value': 1500,
          },
          'title': {'vi': 'Sự kiện riêng'},
          'summary': {'vi': 'Tóm tắt'},
          'citation': {'work': 'Đại Việt sử ký toàn thư'},
          'hero': {
            'id': 'rieng-hero',
            'type': 'image',
            'role': 'hero',
            'flagship': 'events/rieng/hero.png',
            'reduced': 'events/rieng/hero.png',
          },
          if (figures.isNotEmpty) 'figureIds': figures,
        };

    test('the real content loads and validates through the draft', () async {
      final (c, _) = await startReal();
      expectValid(c, 'untouched');
      final d = c.read(contentDraftProvider).requireValue;
      expect(d.events, hasLength(237));
      expect(d.standaloneEvents, isEmpty);
    });

    test('create standalone → move into an era → out again → delete, valid at every step', () async {
      final (c, n) = await startReal();
      final d0 = c.read(contentDraftProvider).requireValue;
      // A person already on a roster, so the standalone rule is satisfied.
      final person = d0.peopleOnAnyRoster.first;

      n.addStandaloneEvent('rieng', standalone(figures: [person]));
      expectValid(c, 'create standalone');
      expect(c.read(contentDraftProvider).requireValue.standaloneEvents.map((e) => e['id']), ['rieng']);

      n.moveEventToEra('rieng', 'nha-trieu');
      expectValid(c, 'move into nha-trieu');
      expect(c.read(contentDraftProvider).requireValue.eraSlugOfEvent('rieng'), 'nha-trieu');

      n.removeEventFromEra('rieng');
      expectValid(c, 'remove from era');

      n.deleteEvent('rieng');
      expectValid(c, 'delete');
      expect(c.read(contentDraftProvider).requireValue.events, hasLength(237));
    });

    test('adding an event to an era and deleting an existing one stay valid', () async {
      final (c, n) = await startReal();
      n.addEvent('nha-trieu', 'moi-trong-nha-trieu', standalone());
      expectValid(c, 'add to era');
      n.deleteEvent('moi-trong-nha-trieu');
      expectValid(c, 'delete it again');
      // An existing event: related links and any streets must be cleaned.
      final d = c.read(contentDraftProvider).requireValue;
      final withStreet = d.referencesTo('chien-thang-bach-dang');
      n.deleteEvent('chien-thang-bach-dang');
      expectValid(c, 'delete a real event (${withStreet.streets.length} streets, ${withStreet.relatedFrom.length} related)');
    });

    test('moving an existing event to another era keeps everything valid', () async {
      final (c, n) = await startReal();
      final d = c.read(contentDraftProvider).requireValue;
      final id = d.eventIdsByEra['nha-trieu']!.first;
      n.moveEventToEra(id, 'au-lac');
      expectValid(c, 'move $id nha-trieu → au-lac');
      expect(c.read(contentDraftProvider).requireValue.eraSlugOfEvent(id), 'au-lac');
    });
  });

  group('ContentDraftController — commit', () {
    test('commit sends exactly the pending diff and settles the new sha', () async {
      final files = _fixtureFiles();
      final lastCommit = <String, dynamic>{};
      final container = ProviderContainer(
        overrides: [cmsApiClientProvider.overrideWithValue(_fakeClient(files, lastCommit: lastCommit))],
      );
      addTearDown(container.dispose);
      await container.read(contentDraftProvider.future);

      container.read(contentDraftProvider.notifier).deleteEra('era-b');
      await container.read(contentDraftProvider.notifier).commit('test: remove era-b');

      expect(lastCommit['baseSha'], 'sha-0');
      expect(lastCommit['message'], 'test: remove era-b');
      final sentFiles = (lastCommit['files'] as Map).cast<String, dynamic>();
      expect(sentFiles['content/eras/era-b.json'], isNull);
      expect(sentFiles.containsKey('content/index.json'), isTrue);

      final draft = container.read(contentDraftProvider).requireValue;
      expect(draft.baseSha, 'sha-1');
      expect(draft.isDirty, isFalse);
    });
  });
}
