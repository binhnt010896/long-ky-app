import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/widgets/narration_button.dart';
import 'package:viet_su/state/providers.dart';
import 'package:viet_su/state/narration_controller.dart';
import 'package:viet_su/state/narration_store.dart';
import 'package:viet_su/telemetry/telemetry.dart';
import 'package:core_domain/core_domain.dart' show Lang;

class _MemStore implements NarrationStore {
  NarrationPrefs prefs = const NarrationPrefs();
  @override
  Future<NarrationPrefs> load() async => prefs;
  @override
  Future<void> save(NarrationPrefs p) async => prefs = p;
}

class _FakePlayer implements NarrationPlayer {
  final _pos = StreamController<Duration>.broadcast();
  final _dur = StreamController<Duration?>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _done = StreamController<bool>.broadcast();
  final loaded = <String>[];
  bool failLoad = false;

  @override
  Stream<Duration> get positionStream => _pos.stream;
  @override
  Stream<Duration?> get durationStream => _dur.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<bool> get completedStream => _done.stream;
  @override
  Future<void> load(String url) async {
    if (failLoad) throw Exception('404');
    loaded.add(url);
    _dur.add(const Duration(seconds: 10));
  }

  @override
  Future<void> play() async => _playing.add(true);
  @override
  Future<void> pause() async => _playing.add(false);
  @override
  Future<void> rewind() async {}
  @override
  void dispose() {}

  void finish() => _done.add(true);
  void at(Duration d) => _pos.add(d);
}

class _Events implements Telemetry {
  final names = <String>[];
  @override
  Future<void> event(String name, [Map<String, Object> params = const {}]) async =>
      names.add(name);
  @override
  Future<void> screen(String name, [Map<String, Object> params = const {}]) async {}
  @override
  Future<void> recordError(Object error, StackTrace stackTrace,
      {String? reason, bool fatal = false}) async {}
  @override
  Future<void> setEnabled(bool enabled) async {}
}


void main() {
  testWidgets('autoplays, first stop asks, Tắt turns autoplay off', (tester) async {
    final store = _MemStore();
    final player = _FakePlayer();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        narrationStoreProvider.overrideWithValue(store),
        narrationPlayerProvider.overrideWithValue(player),
        telemetryProvider.overrideWithValue(_Events()),
        narrationManifestLoaderProvider
            .overrideWithValue(() async => {'eras/ngo-quyen': 'v1'}),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Center(
            child: NarrationButton(kind: NarrationKind.era, id: 'ngo-quyen'),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(player.loaded.single, endsWith('/eras/ngo-quyen.mp3?v=v1'));
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byKey(const Key('narration-button')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Tự phát lời kể?'), findsOneWidget);

    await tester.tap(find.text('Tắt'));
    await tester.pumpAndSettle();
    expect(store.prefs.autoplay, isFalse);
    expect(store.prefs.popupAsked, isTrue);
    expect(find.text('Tự phát lời kể?'), findsNothing);
  });

  testWidgets('hides itself in English', (tester) async {
    final player = _FakePlayer();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        narrationStoreProvider.overrideWithValue(_MemStore()),
        narrationPlayerProvider.overrideWithValue(player),
        telemetryProvider.overrideWithValue(_Events()),
        langProvider.overrideWith((ref) => Lang.en),
        narrationManifestLoaderProvider
            .overrideWithValue(() async => {'eras/a': 'v1'}),
      ],
      child: const MaterialApp(
        home: Scaffold(body: NarrationButton(kind: NarrationKind.era, id: 'a')),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const Key('narration-button')), findsNothing);
    expect(player.loaded, isEmpty);
  });
}
