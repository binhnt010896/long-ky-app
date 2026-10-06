import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../../telemetry/telemetry.dart';

/// Timing of the street map's startup, to find out where the time goes: the
/// splash warm-up (data, archive, prefetch), the screen opening, the tile
/// reads, and the frames drawn while the tiles paint. Marks are milliseconds
/// since the first mark of the app run, so the splash and the screen share one
/// clock. Each screen visit ends in one [report]: a `[street-perf]` line in the
/// log (`adb logcat -s flutter`) and, where telemetry is on, one
/// `street_map_timing` event.
class StreetPerf {
  StreetPerf._();
  static final StreetPerf instance = StreetPerf._();

  final Stopwatch _clock = Stopwatch()..start();
  final Map<String, int> _marks = <String, int>{};

  // One screen visit.
  bool _open = false;
  int _tiles = 0;
  int _tileBytes = 0;
  int _tileErrors = 0;
  int _frames = 0;
  int _jank = 0;
  int _maxBuildMs = 0;
  int _maxRasterMs = 0;
  Timer? _settle;
  Timer? _cap;
  Telemetry? _telemetry;

  /// Records [name] once per app run (the first time wins).
  void mark(String name) => _marks.putIfAbsent(name, () => _clock.elapsedMilliseconds);

  /// The map screen opened: starts counting tiles and frames.
  void beginMapOpen(Telemetry telemetry) {
    _telemetry = telemetry;
    _open = true;
    _tiles = _tileBytes = _tileErrors = _frames = _jank = 0;
    _maxBuildMs = _maxRasterMs = 0;
    _marks
      ..remove('tile_first_request')
      ..remove('tile_first_done')
      ..remove('tile_last_done')
      ..remove('map_open');
    mark('map_open');
    SchedulerBinding.instance.addTimingsCallback(_onFrames);
    // Whatever happens, report after 20 s.
    _cap?.cancel();
    _cap = Timer(const Duration(seconds: 20), report);
  }

  void _onFrames(List<FrameTiming> timings) {
    if (!_open) return;
    for (final t in timings) {
      _frames++;
      final build = t.buildDuration.inMilliseconds;
      final raster = t.rasterDuration.inMilliseconds;
      if (build > _maxBuildMs) _maxBuildMs = build;
      if (raster > _maxRasterMs) _maxRasterMs = raster;
      if (t.totalSpan.inMilliseconds > 17) _jank++;
    }
  }

  void tileRequested() {
    if (!_open) return;
    mark('tile_first_request');
  }

  void tileDone(int bytes, {bool failed = false}) {
    if (!_open) return;
    mark('tile_first_done');
    _marks['tile_last_done'] = _clock.elapsedMilliseconds;
    if (failed) {
      _tileErrors++;
    } else {
      _tiles++;
      _tileBytes += bytes;
    }
    // Report once no tile has arrived for 2 s: the map has settled.
    _settle?.cancel();
    _settle = Timer(const Duration(seconds: 2), report);
  }

  /// Ends the visit (also when the screen closes first).
  void report() {
    if (!_open) return;
    _open = false;
    _settle?.cancel();
    _cap?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onFrames);
    final open = _marks['map_open'] ?? 0;
    int? since(String k) => _marks[k] == null ? null : _marks[k]! - open;
    final params = <String, Object>{
      // Before the screen: negative = the splash got there first.
      'splash_data_ms': _marks['splash_data_ready'] ?? -1,
      'splash_archive_ms': _marks['archive_open'] ?? -1,
      'splash_prefetch_ms': _marks['splash_prefetch_done'] ?? -1,
      'open_at_ms': open,
      // After the screen opened, relative to it.
      'basemap_ready_ms': since('map_basemap_ready') ?? -1,
      'first_tile_req_ms': since('tile_first_request') ?? -1,
      'first_tile_ms': since('tile_first_done') ?? -1,
      'last_tile_ms': since('tile_last_done') ?? -1,
      'tiles': _tiles,
      'tile_kb': _tileBytes ~/ 1024,
      'tile_errors': _tileErrors,
      'frames': _frames,
      'jank_frames': _jank,
      'max_build_ms': _maxBuildMs,
      'max_raster_ms': _maxRasterMs,
    };
    debugPrint('[street-perf] ${params.entries.map((e) => '${e.key}=${e.value}').join(' ')}');
    unawaited(_telemetry?.event('street_map_timing', params));
  }
}

/// Wraps the base map's tile provider to time every tile read.
class TimedTileProvider extends VectorTileProvider {
  TimedTileProvider(this._inner);

  final VectorTileProvider _inner;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    StreetPerf.instance.tileRequested();
    try {
      final bytes = await _inner.provide(tile);
      StreetPerf.instance.tileDone(bytes.length);
      return bytes;
    } catch (_) {
      StreetPerf.instance.tileDone(0, failed: true);
      rethrow;
    }
  }

  @override
  int get maximumZoom => _inner.maximumZoom;

  @override
  int get minimumZoom => _inner.minimumZoom;

  @override
  TileProviderType get type => _inner.type;
}
