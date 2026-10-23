import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../telemetry/telemetry.dart';
import '../theme/content_assets.dart';
import 'narration_store.dart';

/// Which registry a narration belongs to; [segment] is its path on the CDN
/// and the prefix of its key.
enum NarrationKind {
  era('eras'),
  person('people'),
  event('events');

  const NarrationKind(this.segment);
  final String segment;
}

String narrationKey(NarrationKind kind, String id) => '${kind.segment}/$id';

/// Vietnamese narration for a key, published next to the media on the CDN.
/// [v] is the manifest's version of the clip: it busts the cache when a clip is
/// regenerated under the same file name.
String narrationUrl(String key, [String? v]) =>
    '$kContentMediaBase/audio/vi/$key.mp3${v == null ? '' : '?v=$v'}';

/// Which clips exist: key → version. Null when the manifest can't be fetched
/// (offline), in which case nothing is narrated rather than guessing.
typedef NarrationManifest = Map<String, String>;
typedef NarrationManifestLoader = Future<NarrationManifest?> Function();

Future<NarrationManifest?> fetchNarrationManifest() async {
  try {
    final res = await http
        .get(Uri.parse('$kContentMediaBase/audio/manifest.json'))
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return null;
    final raw = jsonDecode(res.body);
    final clips = raw is Map<String, dynamic> ? raw['clips'] : null;
    if (clips is! Map<String, dynamic>) return null;
    return <String, String>{
      for (final e in clips.entries)
        if (e.value is Map<String, dynamic> &&
            (e.value as Map<String, dynamic>)['v'] is String)
          e.key: (e.value as Map<String, dynamic>)['v'] as String,
    };
  } catch (_) {
    return null;
  }
}

/// The audio seam — just_audio in the app, a fake in tests.
abstract class NarrationPlayer {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;
  Stream<bool> get completedStream;

  /// Loads [url]; throws when the clip is missing or unreachable.
  Future<void> load(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> rewind();
  void dispose();
}

/// just_audio behind the seam. The platform player is only created on the
/// first [load], so merely having the provider alive (every narrated screen
/// reads it) costs nothing and touches no platform channel.
class JustAudioNarrationPlayer implements NarrationPlayer {
  AudioPlayer? _player;
  final StreamController<Duration> _position = StreamController<Duration>.broadcast();
  final StreamController<Duration?> _duration = StreamController<Duration?>.broadcast();
  final StreamController<bool> _playing = StreamController<bool>.broadcast();
  final StreamController<bool> _completed = StreamController<bool>.broadcast();
  final List<StreamSubscription<Object?>> _subs = <StreamSubscription<Object?>>[];

  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<Duration?> get durationStream => _duration.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<bool> get completedStream => _completed.stream;

  AudioPlayer _ensure() {
    final existing = _player;
    if (existing != null) return existing;
    final p = _player = AudioPlayer();
    _subs
      ..add(p.positionStream.listen(_position.add))
      ..add(p.durationStream.listen(_duration.add))
      ..add(p.playingStream.listen(_playing.add))
      ..add(p.processingStateStream
          .listen((s) => _completed.add(s == ProcessingState.completed)));
    return p;
  }

  @override
  Future<void> load(String url) async {
    await _ensure().setUrl(url);
  }

  // play() only completes when playback ends, so it is never awaited.
  @override
  Future<void> play() async => unawaited(_ensure().play());
  @override
  Future<void> pause() async => _player?.pause();
  @override
  Future<void> rewind() async {
    final p = _player;
    if (p == null) return;
    await p.pause();
    await p.seek(Duration.zero);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    _position.close();
    _duration.close();
    _playing.close();
    _completed.close();
  }
}

class NarrationState {
  const NarrationState({
    this.key,
    this.playing = false,
    this.loading = false,
    this.failed = false,
    this.progress = 0,
    this.prefs = const NarrationPrefs(),
    this.askPending = false,
  });

  /// The page the reader is on (loaded or not); null when none has narration.
  final String? key;
  final bool playing;
  final bool loading;

  /// The clip for [key] could not be loaded — the button hides itself.
  final bool failed;

  /// 0..1 through the clip.
  final double progress;
  final NarrationPrefs prefs;

  /// The one-time "keep autoplay?" question should be shown now.
  final bool askPending;

  NarrationState copyWith({
    String? key,
    bool clearKey = false,
    bool? playing,
    bool? loading,
    bool? failed,
    double? progress,
    NarrationPrefs? prefs,
    bool? askPending,
  }) =>
      NarrationState(
        key: clearKey ? null : (key ?? this.key),
        playing: playing ?? this.playing,
        loading: loading ?? this.loading,
        failed: failed ?? this.failed,
        progress: progress ?? this.progress,
        prefs: prefs ?? this.prefs,
        askPending: askPending ?? this.askPending,
      );
}

/// One narration at a time, app-wide. Pages call [enter]/[leave] as they
/// appear and disappear; the first visit to a page autoplays (if the reader
/// allows it); the reader's first manual stop asks, once, whether to keep that.
class NarrationController extends StateNotifier<NarrationState> {
  NarrationController({
    required this.store,
    required this.player,
    required this.telemetry,
    required this.manifest,
  }) : super(const NarrationState()) {
    _subs
      ..add(player.positionStream.listen(_onPosition))
      ..add(player.durationStream.listen((d) => _duration = d))
      ..add(player.playingStream.listen(_onPlaying))
      ..add(player.completedStream.listen(_onCompleted));
    _prefsReady = store.load().then((p) {
      if (mounted) state = state.copyWith(prefs: p);
    });
  }

  final NarrationStore store;
  final NarrationPlayer player;
  final Telemetry telemetry;
  final NarrationManifestLoader manifest;
  Future<NarrationManifest?>? _manifestFuture;
  NarrationManifest? _clips;
  final List<StreamSubscription<Object?>> _subs = <StreamSubscription<Object?>>[];
  late final Future<void> _prefsReady;
  Duration? _duration;
  String? _loadedKey;

  /// A page with narration appeared. Starts it on a first visit if allowed.
  Future<void> enter(String key) async {
    await _prefsReady;
    if (!mounted) return;
    if (state.key == key) return;
    await _halt();
    state = NarrationState(prefs: state.prefs, key: key);
    // Retry the manifest next time if this fetch failed.
    _clips = await (_manifestFuture ??= manifest());
    if (_clips == null) _manifestFuture = null;
    if (!mounted || state.key != key) return;
    if (_clips?[key] == null) {
      state = state.copyWith(failed: true); // no clip: the button hides
      return;
    }
    if (state.prefs.autoplay && !state.prefs.heard.contains(key)) {
      await _start(key, auto: true);
    }
  }

  /// The page left the screen; stops its narration.
  Future<void> leave(String key) async {
    if (!mounted || state.key != key) return;
    if (state.playing) telemetry.event('narration_leave', _listened(key));
    await _halt();
    state = NarrationState(prefs: state.prefs);
  }

  /// The play/pause button.
  Future<void> toggle() async {
    final key = state.key;
    if (key == null || state.loading) return;
    if (state.playing) {
      await player.pause();
      telemetry.event('narration_stop', _listened(key));
      if (!state.prefs.popupAsked && state.prefs.autoplay) {
        state = state.copyWith(askPending: true);
      }
    } else {
      await _start(key, auto: false);
    }
  }

  /// The answer to the one-time question (also from the Sảnh switch).
  Future<void> answerAutoplay(bool keep) async {
    final prefs = state.prefs.copyWith(autoplay: keep, popupAsked: true);
    state = state.copyWith(prefs: prefs, askPending: false);
    telemetry.event(
        'narration_autoplay_choice', <String, Object>{'keep': keep ? 1 : 0});
    await store.save(prefs);
  }

  /// The Sảnh switch: counts as an answer, so the question is never asked.
  Future<void> setAutoplay(bool on) async {
    final prefs = state.prefs.copyWith(autoplay: on, popupAsked: true);
    state = state.copyWith(prefs: prefs, askPending: false);
    await store.save(prefs);
  }

  Future<void> _start(String key, {required bool auto}) async {
    state = state.copyWith(loading: true, failed: false);
    try {
      if (_loadedKey != key) {
        _loadedKey = null;
        await player.load(narrationUrl(key, _clips?[key]));
        _loadedKey = key;
      }
      if (!mounted || state.key != key) return;
      final prefs = state.prefs.copyWith(heard: <String>{...state.prefs.heard, key});
      state = state.copyWith(loading: false, prefs: prefs);
      unawaited(store.save(prefs));
      await player.play();
      telemetry.event('narration_play', <String, Object>{
        'kind': _kindOf(key),
        'id': _idOf(key),
        'auto': auto ? 1 : 0,
      });
    } catch (_) {
      // Offline, or no clip published for this page yet: stay silent.
      if (mounted) state = state.copyWith(loading: false, failed: true);
    }
  }

  Future<void> _halt() async {
    if (state.playing) await player.pause();
    _loadedKey = null;
  }

  void _onPosition(Duration p) {
    final d = _duration;
    if (d == null || d.inMilliseconds == 0 || !state.playing) return;
    final v = (p.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0);
    if ((v - state.progress).abs() >= 0.005) state = state.copyWith(progress: v);
  }

  void _onPlaying(bool playing) {
    if (mounted && playing != state.playing) {
      state = state.copyWith(playing: playing);
    }
  }

  Future<void> _onCompleted(bool done) async {
    if (!done) return;
    final key = state.key;
    if (key != null) {
      telemetry.event('narration_complete',
          <String, Object>{'kind': _kindOf(key), 'id': _idOf(key)});
    }
    await player.rewind();
    if (mounted) state = state.copyWith(playing: false, progress: 0);
  }

  String _kindOf(String key) => key.split('/').first;
  String _idOf(String key) => key.substring(key.indexOf('/') + 1);

  /// How far into the clip the reader got, for `narration_stop` (the pause
  /// button) and `narration_leave` (the page closed while it played).
  Map<String, Object> _listened(String key) => <String, Object>{
        'kind': _kindOf(key),
        'id': _idOf(key),
        'listened_pct': (state.progress * 100).round(),
      };

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

final narrationStoreProvider =
    Provider<NarrationStore>((ref) => FileNarrationStore());

final narrationPlayerProvider = Provider<NarrationPlayer>((ref) {
  final player = JustAudioNarrationPlayer();
  ref.onDispose(player.dispose);
  return player;
});

final narrationManifestLoaderProvider =
    Provider<NarrationManifestLoader>((ref) => fetchNarrationManifest);

final narrationProvider =
    StateNotifierProvider<NarrationController, NarrationState>((ref) {
  return NarrationController(
    store: ref.watch(narrationStoreProvider),
    player: ref.watch(narrationPlayerProvider),
    telemetry: ref.watch(telemetryProvider),
    manifest: ref.watch(narrationManifestLoaderProvider),
  );
});
