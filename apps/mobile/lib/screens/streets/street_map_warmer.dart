import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'street_basemap.dart';
import 'street_data.dart';
import 'street_map_screen.dart' show kStreetMaxZoom, kStreetMinZoom;
import 'street_perf.dart';

/// Turned on by the splash once the base map archive is open: from then on
/// [StreetMapWarmer] draws the map's first view out of sight.
final streetWarmProvider = StateProvider<bool>((ref) => false);

/// Whether the warm-up has drawn enough: some tile images are on disk and no
/// new ones appeared for [stableTicks] checks in a row, or [elapsed] ran out.
bool warmFinished({
  required int images,
  required int stableTicks,
  required Duration elapsed,
  int needStable = 3,
  Duration cap = const Duration(seconds: 15),
}) =>
    elapsed >= cap || (images > 0 && stableTicks >= needStable);

/// Draws the street map's first view once, out of sight, so its tiles are
/// already rendered on disk when the screen opens.
///
/// vector_map_tiles (raster mode) turns each vector tile into an image on the
/// phone and keeps the images in its disk cache; opening the map a second time
/// is fast only because of that. This does the first draw behind the splash:
/// a map of the screen's size at the start view, with the same theme, tile
/// source and cache folder as the real one, laid out but never painted
/// ([Offstage]). It removes itself when the image count in the cache stops
/// growing. Not run on web (no disk cache) or when there is no base map.
class StreetMapWarmer extends ConsumerStatefulWidget {
  const StreetMapWarmer({super.key});

  @override
  ConsumerState<StreetMapWarmer> createState() => _StreetMapWarmerState();
}

class _StreetMapWarmerState extends ConsumerState<StreetMapWarmer> {
  final vtr.Theme _theme = buildStreetBasemapTheme();
  final Stopwatch _clock = Stopwatch();
  Timer? _poll;
  bool _started = false;
  bool _done = false;
  int _last = -1;
  int _stable = 0;
  int _frames = 0;
  int _jank = 0;

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _onFrames(List<FrameTiming> timings) {
    for (final t in timings) {
      _frames++;
      if (t.totalSpan.inMilliseconds > 17) _jank++;
    }
  }

  void _start(StreetBasemap basemap) {
    if (_started) return;
    _started = true;
    _clock.start();
    StreetPerf.instance.mark('warm_start');
    SchedulerBinding.instance.addTimingsCallback(_onFrames);
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) => _check(basemap));
  }

  Future<void> _check(StreetBasemap basemap) async {
    var images = 0;
    try {
      final dir = await basemap.cacheFolder();
      if (await dir.exists()) {
        images = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).length;
      }
    } catch (_) {
      // Unreadable folder: the cap ends the warm-up.
    }
    _stable = images == _last ? _stable + 1 : 0;
    _last = images;
    if (warmFinished(images: images, stableTicks: _stable, elapsed: _clock.elapsed)) {
      _stop();
      StreetPerf.instance.mark('warm_done');
      debugPrint('[street-perf] warm images=$images ms=${_clock.elapsedMilliseconds} '
          'frames=$_frames jank_frames=$_jank');
      if (mounted) setState(() => _done = true);
    }
  }

  void _stop() {
    _poll?.cancel();
    _poll = null;
    if (_started) SchedulerBinding.instance.removeTimingsCallback(_onFrames);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || _done || !ref.watch(streetWarmProvider)) return const SizedBox.shrink();
    final data = ref.watch(streetMapDataProvider).valueOrNull;
    final basemap = ref.watch(streetBasemapProvider).valueOrNull;
    final start = data?.file.start;
    if (data == null || basemap == null || start == null) return const SizedBox.shrink();
    _start(basemap);
    final size = MediaQuery.sizeOf(context);
    return Offstage(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: FlutterMap(
          options: MapOptions(
            minZoom: kStreetMinZoom,
            maxZoom: kStreetMaxZoom,
            initialCenter: LatLng(start.lat, start.lng),
            initialZoom: start.zoom.clamp(kStreetMinZoom, kStreetMaxZoom),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: <Widget>[
            VectorTileLayer(
              theme: _theme,
              cacheFolder: basemap.cacheFolder,
              tileProviders: basemap.providers,
              concurrency: kBasemapConcurrency,
              fileCacheTtl: kBasemapTileTtl,
            ),
          ],
        ),
      ),
    );
  }
}
