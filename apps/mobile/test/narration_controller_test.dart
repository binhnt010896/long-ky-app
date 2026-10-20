import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/state/narration_controller.dart';
import 'package:viet_su/state/narration_store.dart';
import 'package:viet_su/telemetry/telemetry.dart';

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

/// A manifest that has every clip.
class _AllClips extends MapBase<String, String> {
  @override
  String? operator [](Object? key) => 'v1';
  @override
  void operator []=(String key, String value) {}
  @override
  void clear() {}
  @override
  Iterable<String> get keys => const <String>[];
  @override
  String? remove(Object? key) => null;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _MemStore store;
  late _FakePlayer player;
  late _Events events;
  NarrationManifest? clips;
  NarrationController make() => NarrationController(
      store: store, player: player, telemetry: events,
      manifest: () async => clips);

  setUp(() {
    store = _MemStore();
    player = _FakePlayer();
    events = _Events();
    clips = _AllClips();
  });

  test('first visit autoplays and is remembered as heard', () async {
    final c = make();
    await c.enter('eras/ngo-quyen');
    await _settle();
    expect(player.loaded.single, endsWith('/audio/vi/eras/ngo-quyen.mp3?v=v1'));
    expect(c.state.playing, isTrue);
    expect(store.prefs.heard, contains('eras/ngo-quyen'));
    expect(events.names, contains('narration_play'));
  });

  test('a heard page does not autoplay again', () async {
    store.prefs = const NarrationPrefs(heard: {'people/le-loi'});
    final c = make();
    await c.enter('people/le-loi');
    await _settle();
    expect(player.loaded, isEmpty);
    expect(c.state.playing, isFalse);
    await c.toggle(); // manual play still works
    await _settle();
    expect(c.state.playing, isTrue);
  });

  test('autoplay off: nothing starts by itself', () async {
    store.prefs = const NarrationPrefs(autoplay: false);
    final c = make();
    await c.enter('events/x');
    await _settle();
    expect(player.loaded, isEmpty);
  });

  test('first manual stop asks once; the answer is saved and never re-asked', () async {
    final c = make();
    await c.enter('eras/a');
    await _settle();
    await c.toggle(); // stop
    await _settle();
    expect(c.state.askPending, isTrue);

    await c.answerAutoplay(false);
    expect(c.state.askPending, isFalse);
    expect(store.prefs.autoplay, isFalse);
    expect(store.prefs.popupAsked, isTrue);

    await c.toggle(); // play again
    await _settle();
    await c.toggle(); // stop again
    await _settle();
    expect(c.state.askPending, isFalse);
    expect(events.names, contains('narration_autoplay_choice'));
  });

  test('keeping autoplay is saved too', () async {
    final c = make();
    await c.enter('eras/a');
    await _settle();
    await c.toggle();
    await c.answerAutoplay(true);
    expect(store.prefs.autoplay, isTrue);
    expect(store.prefs.popupAsked, isTrue);
  });

  test('the Sảnh switch counts as the answer', () async {
    final c = make();
    await c.setAutoplay(false);
    expect(store.prefs.autoplay, isFalse);
    expect(store.prefs.popupAsked, isTrue);
  });

  test('moving to another page stops the first and autoplays the second', () async {
    final c = make();
    await c.enter('eras/a');
    await _settle();
    await c.enter('people/b');
    await _settle();
    expect(player.loaded, hasLength(2));
    expect(c.state.key, 'people/b');
    expect(c.state.playing, isTrue);
  });

  test('leaving stops and clears', () async {
    final c = make();
    await c.enter('eras/a');
    await _settle();
    await c.leave('eras/a');
    await _settle();
    expect(c.state.key, isNull);
    expect(c.state.playing, isFalse);
  });

  test('a page not in the manifest never requests a clip', () async {
    clips = <String, String>{'eras/other': 'v1'};
    final c = make();
    await c.enter('events/none');
    await _settle();
    expect(player.loaded, isEmpty);
    expect(c.state.failed, isTrue);
  });

  test('an unreachable manifest narrates nothing', () async {
    clips = null;
    final c = make();
    await c.enter('eras/a');
    await _settle();
    expect(player.loaded, isEmpty);
    expect(c.state.failed, isTrue);
  });

  test('the clip is requested with its manifest version', () async {
    clips = <String, String>{'eras/a': 'abc123'};
    final c = make();
    await c.enter('eras/a');
    await _settle();
    expect(player.loaded.single, endsWith('/eras/a.mp3?v=abc123'));
  });

  test('a missing clip marks failed without throwing', () async {
    player.failLoad = true;
    final c = make();
    await c.enter('events/none');
    await _settle();
    expect(c.state.failed, isTrue);
    expect(c.state.playing, isFalse);
  });

  test('progress follows the position and resets when the clip ends', () async {
    final c = make();
    await c.enter('eras/a');
    await _settle();
    player.at(const Duration(seconds: 5));
    await _settle();
    expect(c.state.progress, closeTo(0.5, 0.01));
    player.finish();
    await _settle();
    expect(c.state.playing, isFalse);
    expect(c.state.progress, 0);
  });
}
