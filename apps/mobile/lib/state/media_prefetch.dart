import 'dart:async' show unawaited;

import 'package:core_domain/core_domain.dart';

import '../theme/content_assets.dart';

/// Downloads era media into the shared on-device cache ahead of when the
/// user scrolls to it, so a Home swipe or an Era Hub open rarely has to wait
/// on the network. Never throws and never blocks the UI thread beyond the
/// awaited [warm] call the splash uses for the very first page.
class MediaPrefetcher {
  MediaPrefetcher._();

  static final MediaPrefetcher instance = MediaPrefetcher._();

  /// How many dynasties beyond the current one to keep warm in the background.
  static const int prefetchAhead = 3;

  /// How many files to download at once.
  static const int concurrency = 3;

  final Set<String> _inFlight = <String>{};
  int _generation = 0;

  /// Downloads [paths] now, awaiting completion. Used by the splash for the
  /// first Home page so it can show a progress bar. Already-cached files are
  /// counted as done immediately. Never throws.
  Future<void> warm(
    Iterable<String> paths, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (debugContentImageOverride != null) return;
    final urls = <String>{for (final p in paths) ContentMedia.url(p)};
    final total = urls.length;
    if (total == 0) {
      onProgress?.call(0, 0);
      return;
    }
    var done = 0;
    onProgress?.call(done, total);
    final queue = urls.toList();
    var cursor = 0;

    Future<void> worker() async {
      while (true) {
        final int i;
        if (cursor >= queue.length) return;
        i = cursor++;
        await _fetch(queue[i]);
        done++;
        onProgress?.call(done, total);
      }
    }

    await Future.wait(
        <Future<void>>[for (var i = 0; i < concurrency; i++) worker()]);
  }

  /// Fire-and-forget background prefetch. Replaces whatever this instance was
  /// working through — the latest call wins, so scrolling to a new dynasty
  /// drops the previous window's remaining downloads. In-flight downloads
  /// finish; they aren't cancelled. Never throws.
  void queue(Iterable<String> paths) {
    if (debugContentImageOverride != null) return;
    final generation = ++_generation;
    final urls = <String>{for (final p in paths) ContentMedia.url(p)};
    unawaited(_runQueue(generation, urls.toList()));
  }

  Future<void> _runQueue(int generation, List<String> urls) async {
    var cursor = 0;

    Future<void> worker() async {
      while (true) {
        if (generation != _generation) return; // superseded by a newer queue
        final int i;
        if (cursor >= urls.length) return;
        i = cursor++;
        await _fetch(urls[i]);
      }
    }

    await Future.wait(
        <Future<void>>[for (var i = 0; i < concurrency; i++) worker()]);
  }

  Future<void> _fetch(String url) async {
    if (_inFlight.contains(url)) return;
    _inFlight.add(url);
    try {
      final cached = await ContentMedia.cache.getFileFromCache(url);
      if (cached == null) {
        await ContentMedia.cache.downloadFile(url);
      }
    } catch (_) {
      // A failed prefetch is never fatal — the widget that actually needs
      // the image will retry (and show its own fallback) when it's opened.
    } finally {
      _inFlight.remove(url);
    }
  }
}

/// Every media path a dynasty's Home page can show: the period cover, then
/// each era's scene layers in order (both tiers, since the active tier isn't
/// known here). Skips animated covers (`video`) — those are pulled in
/// separately, and are heavy.
List<String> homeMediaFor(Dynasty dynasty) {
  final out = <String>[];
  final seen = <String>{};
  void add(String? path) {
    if (path != null && seen.add(path)) out.add(path);
  }

  add(dynasty.period.cover?.flagship);
  add(dynasty.period.cover?.reduced);
  for (final era in dynasty.eras) {
    for (final layer in era.sceneLayers) {
      add(layer.flagship);
      add(layer.reduced);
    }
  }
  return out;
}

/// Just enough of a dynasty's Home page to show immediately: the period
/// cover plus its first era's scene layers. Used by the splash warm-up.
List<String> firstPageMediaFor(Dynasty dynasty) {
  final out = <String>[];
  final seen = <String>{};
  void add(String? path) {
    if (path != null && seen.add(path)) out.add(path);
  }

  add(dynasty.period.cover?.flagship);
  add(dynasty.period.cover?.reduced);
  if (dynasty.eras.isNotEmpty) {
    for (final layer in dynasty.eras.first.sceneLayers) {
      add(layer.flagship);
      add(layer.reduced);
    }
  }
  return out;
}

/// Every media path an Era Hub can show: each event's hero, each character's
/// avatar/fullBody (or legacy portrait sheet), the era cover, then the scene
/// layers' animated `video`s last — those are the heaviest downloads and the
/// hub is usable without them (the still poster shows meanwhile).
List<String> eraHubMediaFor(Era era) {
  final out = <String>[];
  final seen = <String>{};
  void add(String? path) {
    if (path != null && seen.add(path)) out.add(path);
  }

  for (final event in era.events) {
    add(event.hero?.flagship);
    add(event.hero?.reduced);
  }
  for (final character in era.characters) {
    add(character.avatar?.flagship);
    add(character.avatar?.reduced);
    add(character.fullBody?.flagship);
    add(character.fullBody?.reduced);
    add(character.portrait?.flagship);
    add(character.portrait?.reduced);
  }
  add(era.cover?.flagship);
  add(era.cover?.reduced);
  for (final layer in era.sceneLayers) {
    add(layer.video);
  }
  return out;
}

/// The rolling prefetch window around Home's active dynasty [i]: its own
/// media, then the next [MediaPrefetcher.prefetchAhead] dynasties, then the
/// one just left behind. Indices are clamped to the list; the result is
/// deduped, keeping the first (most urgent) occurrence of each path.
List<String> prefetchWindow(List<Dynasty> dynasties, int i) {
  final out = <String>[];
  final seen = <String>{};
  void addAll(Iterable<String> paths) {
    for (final p in paths) {
      if (seen.add(p)) out.add(p);
    }
  }

  if (dynasties.isEmpty) return out;
  final current = i.clamp(0, dynasties.length - 1);
  addAll(homeMediaFor(dynasties[current]));
  for (var k = current + 1; k <= current + MediaPrefetcher.prefetchAhead; k++) {
    if (k < dynasties.length) addAll(homeMediaFor(dynasties[k]));
  }
  if (current - 1 >= 0) addAll(homeMediaFor(dynasties[current - 1]));
  return out;
}
