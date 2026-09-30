import 'dart:convert';

import 'package:admin/api/api_providers.dart';
import 'package:admin/api/cms_api_client.dart';
import 'package:admin/screens/events_screen.dart';
import 'package:admin/state/content_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _ev(String id, String title) => {
      'id': id,
      'slug': id,
      'kind': 'historical',
      'year': {'display': {'vi': '1000'}, 'value': 1000},
      'title': {'vi': title},
      'summary': {'vi': 's'},
      'citation': {'work': 'w'},
    };

Map<String, String> _files() => {
      'content/era.schema.json': '{"type":"object"}',
      'content/people.schema.json': '{"type":"object"}',
      'content/period.schema.json': '{"type":"object"}',
      'content/event.schema.json': '{"type":"object"}',
      'content/index.json': jsonEncode({'schemaVersion': 1, 'eras': ['era-a', 'era-b']}),
      'content/people.json': jsonEncode({'schemaVersion': 1, 'people': <dynamic>[]}),
      'content/periods.json': jsonEncode({'schemaVersion': 1, 'periods': <dynamic>[]}),
      'content/media-manifest.json': jsonEncode({'schemaVersion': 2, 'files': <String, dynamic>{}}),
      'content/events.json': jsonEncode({
        'schemaVersion': 1,
        'events': [
          _ev('a1', 'Trong thời A'),
          _ev('a2', 'Cũng thời A'),
          _ev('b1', 'Duy nhất thời B'),
          _ev('alone', 'Sự kiện riêng lẻ'),
        ],
      }),
      'content/eras/era-a.json': jsonEncode({
        'id': 'era-a', 'slug': 'era-a', 'order': 0,
        'title': {'vi': 'A'}, 'characters': <dynamic>[],
        'events': [{'ref': 'a1'}, {'ref': 'a2'}],
      }),
      'content/eras/era-b.json': jsonEncode({
        'id': 'era-b', 'slug': 'era-b', 'order': 1,
        'title': {'vi': 'B'}, 'characters': <dynamic>[],
        'events': [{'ref': 'b1'}],
      }),
      'content/streets/hcm.json': jsonEncode({
        'schemaVersion': 1,
        'city': 'hcm',
        'streets': [
          {
            'id': 'phố-một-đích',
            'name': 'Phố Một Đích',
            'status': 'approved',
            'targets': [{'type': 'event', 'id': 'a1', 'era': 'era-a'}],
          },
        ],
      }),
    };

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final client = CmsApiClient(
    baseUrl: 'https://example.invalid',
    idTokenProvider: () async => 't',
    client: MockClient((req) async => http.Response(
          jsonEncode({'sha': 's0', 'files': _files()}),
          200,
          headers: {'content-type': 'application/json'},
        )),
  );
  final container = ProviderContainer(overrides: [cmsApiClientProvider.overrideWithValue(client)]);
  addTearDown(container.dispose);
  await container.read(contentDraftProvider.future);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: Scaffold(body: EventsScreen())),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('lists every event, counting the standalone ones', (tester) async {
    await _pump(tester);
    expect(find.text('Events (4 · 1 standalone)'), findsOneWidget);
    for (final t in ['Trong thời A', 'Cũng thời A', 'Duy nhất thời B', 'Sự kiện riêng lẻ']) {
      expect(find.text(t), findsOneWidget);
    }
    // Each row says which era it is in, or that it is standalone.
    expect(find.text('Standalone'), findsOneWidget);
    expect(find.text('era-a'), findsNWidgets(2));
  });

  testWidgets('"Standalone only" shows just the events no era lists', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standalone only (1)').last);
    await tester.pumpAndSettle();
    expect(find.text('Sự kiện riêng lẻ'), findsOneWidget);
    expect(find.text('Trong thời A'), findsNothing);
  });

  testWidgets('filtering by an era shows only that era\'s events', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Era: era-b').last);
    await tester.pumpAndSettle();
    expect(find.text('Duy nhất thời B'), findsOneWidget);
    expect(find.text('Trong thời A'), findsNothing);
  });

  testWidgets('search narrows by title', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'riêng');
    await tester.pumpAndSettle();
    expect(find.text('Sự kiện riêng lẻ'), findsOneWidget);
    expect(find.text('Cũng thời A'), findsNothing);
  });

  testWidgets('an era\'s only event cannot be removed from it', (tester) async {
    await _pump(tester);
    // era-b has one event (b1): its link_off button is disabled.
    final row = find.ancestor(of: find.text('Duy nhất thời B'), matching: find.byType(ListTile));
    final unlink = find.descendant(of: row, matching: find.widgetWithIcon(IconButton, Icons.link_off));
    expect(tester.widget<IconButton>(unlink).onPressed, isNull);
    // …but an era with two can.
    final rowA = find.ancestor(of: find.text('Trong thời A'), matching: find.byType(ListTile));
    final unlinkA = find.descendant(of: rowA, matching: find.widgetWithIcon(IconButton, Icons.link_off));
    expect(tester.widget<IconButton>(unlinkA).onPressed, isNotNull);
  });

  testWidgets('removing an event from its era makes it standalone, not deleted', (tester) async {
    final c = await _pump(tester);
    final rowA = find.ancestor(of: find.text('Trong thời A'), matching: find.byType(ListTile));
    await tester.tap(find.descendant(of: rowA, matching: find.widgetWithIcon(IconButton, Icons.link_off)));
    await tester.pumpAndSettle();
    final d = c.read(contentDraftProvider).requireValue;
    expect(d.eventById('a1'), isNotNull);
    expect(d.eraSlugOfEvent('a1'), isNull);
    expect(find.text('Events (4 · 2 standalone)'), findsOneWidget);
  });

  testWidgets('"New standalone event" opens the dialog in standalone mode', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('New standalone event'));
    await tester.pumpAndSettle();
    expect(find.text('New event'), findsOneWidget);
    expect(find.text('Hero image (required for a standalone event)'), findsOneWidget);
    expect(find.textContaining('at least one era\'s roster'), findsOneWidget);
  });

  testWidgets('deleting lists what else changes and needs the id typed', (tester) async {
    final c = await _pump(tester);
    final rowA = find.ancestor(of: find.text('Trong thời A'), matching: find.byType(ListTile));
    await tester.tap(find.descendant(of: rowA, matching: find.widgetWithIcon(IconButton, Icons.delete_outline)));
    await tester.pumpAndSettle();

    expect(find.text('Delete "Trong thời A"'), findsOneWidget);
    expect(find.textContaining('Removed from era: era-a'), findsOneWidget);
    expect(find.textContaining('Phố Một Đích'), findsOneWidget);
    expect(find.textContaining('is removed too'), findsOneWidget);

    // Wrong id: the dialog closes and nothing is deleted.
    await tester.enterText(find.widgetWithText(TextField, 'a1'), 'nope');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(c.read(contentDraftProvider).requireValue.eventById('a1'), isNotNull);

    // Right id: gone from the registry, the era and the street map.
    await tester.tap(find.descendant(of: rowA, matching: find.widgetWithIcon(IconButton, Icons.delete_outline)));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'a1'), 'a1');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    final d = c.read(contentDraftProvider).requireValue;
    expect(d.eventById('a1'), isNull);
    expect(d.eventIdsByEra['era-a'], ['a2']);
    expect((jsonDecode(d.files['content/streets/hcm.json']!) as Map)['streets'], isEmpty);
  });
}
