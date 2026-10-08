import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/screens/prototype/territory_map_demo_screen.dart';
import 'package:viet_su/state/tour_store.dart';
import 'package:viet_su/telemetry/telemetry.dart';

class _Events implements Telemetry {
  final List<(String, Map<String, Object>)> events = [];
  @override
  Future<void> event(String name, [Map<String, Object> params = const {}]) async =>
      events.add((name, params));
  @override
  Future<void> screen(String name, [Map<String, Object> params = const {}]) async {}
  @override
  Future<void> recordError(Object error, StackTrace stackTrace,
      {String? reason, bool fatal = false}) async {}
  @override
  Future<void> setEnabled(bool enabled) async {}
}

class _TourStore implements TourStore {
  _TourStore({this.alreadySeen = true});
  bool alreadySeen;
  int marked = 0;
  @override
  Future<bool> seen() async => alreadySeen;
  @override
  Future<void> markSeen() async {
    alreadySeen = true;
    marked++;
  }
}

Future<_Events> _pump(WidgetTester tester, _TourStore store) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final telemetry = _Events();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      atlasTourStoreProvider.overrideWithValue(store),
      telemetryProvider.overrideWithValue(telemetry),
    ],
    child: const MaterialApp(home: TerritoryMapDemoScreen()),
  ));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  return telemetry;
}

void main() {
  testWidgets('first visit: step 1 is the map, step 2 the timeline, then it is marked seen',
      (tester) async {
    final store = _TourStore(alreadySeen: false);
    final tel = await _pump(tester, store);
    expect(find.byKey(const Key('atlas-coach-text')), findsOneWidget);
    expect(find.textContaining('vùng'), findsWidgets);

    await tester.tap(find.byKey(const Key('atlas-coach-next')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('thanh thời gian'), findsWidgets);

    await tester.tap(find.byKey(const Key('atlas-coach-next')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('atlas-coach-text')), findsNothing);
    expect(store.marked, 1);
    expect(tel.events.where((e) => e.$1 == 'atlas_tour_end').single.$2['result'], 'done');
  });

  testWidgets('skipping also marks it seen', (tester) async {
    final store = _TourStore(alreadySeen: false);
    final tel = await _pump(tester, store);
    await tester.tap(find.byKey(const Key('atlas-coach-skip')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('atlas-coach-text')), findsNothing);
    expect(store.marked, 1);
    expect(tel.events.where((e) => e.$1 == 'atlas_tour_end').single.$2['result'], 'skip');
  });

  testWidgets('not shown once seen', (tester) async {
    final store = _TourStore();
    await _pump(tester, store);
    expect(find.byKey(const Key('atlas-coach-text')), findsNothing);
    expect(store.marked, 0);
  });
}
