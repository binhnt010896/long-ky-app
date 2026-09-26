import 'dart:convert';

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
