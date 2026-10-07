import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../../state/providers.dart';
import '../../state/street_tour_store.dart';
import '../../telemetry/telemetry.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/lang_toggle.dart';
import 'street_basemap.dart';
import 'street_card.dart';
import 'street_coachmarks.dart';
import 'street_data.dart';
import 'street_landmarks.dart';
import 'street_perf.dart';

/// Minimum zoom of the street map. Together with the camera constraint it
/// keeps the open sea and the island chains out of frame (sovereignty guard).
const double kStreetMinZoom = 10;
const double kStreetMaxZoom = 17;

/// Gold streets at rest: gold pulled toward the ground, opaque (so crossings
/// don't brighten), dim enough that the selected street's bright gold stands
/// out against them.
final Color _kRestingStreet = Color.lerp(VSColors.gold, VSColors.lacquer, 0.4)!;

/// "Đường phố mang tên sử" — a map of the streets in old HCMC that are named
/// after a Character or Event in the chronicle. Tap a gold street for its
/// name and what it honours, with a button to that page.
class StreetMapScreen extends ConsumerStatefulWidget {
  const StreetMapScreen({this.initialStreetId, super.key});

  /// `?street=<id>` — open already zoomed to this street with its card up.
  final String? initialStreetId;

  @override
  ConsumerState<StreetMapScreen> createState() => _StreetMapScreenState();
}

class _StreetMapScreenState extends ConsumerState<StreetMapScreen> {
  final MapController _map = MapController();
  String? _selected;

  /// The first-visit tour: shown once, never when the map is opened onto a
  /// street (from a character's chip), and stored as seen when ended.
  bool _tour = false;
  final GlobalKey _cardKey = GlobalKey();
  final TextEditingController _query = TextEditingController();

  // Built ONCE. The vector layer restarts its tile loading whenever the theme
  // or the provider map it is handed changes identity, so creating either in
  // build() (which runs on every selection, search keystroke and data refresh)
  // would keep it from ever finishing a first paint.
  final vtr.Theme _basemapTheme = buildStreetBasemapTheme();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialStreetId;
    StreetPerf.instance.beginMapOpen(ref.read(telemetryProvider));
    if (widget.initialStreetId == null) _maybeStartTour();
  }

  Future<void> _maybeStartTour() async {
    if (await ref.read(streetTourStoreProvider).seen() || !mounted) return;
    // Let the map paint first; the tour is a hint, not a gate.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _tour = true);
  }

  /// A street to open for the tour's second step, so the card the step talks
  /// about is on screen: a well-known one when present, else the first mapped.
  String? _sampleStreet(StreetMapData data) {
    if (data.lines.containsKey('tran-hung-dao')) return 'tran-hung-dao';
    for (final st in data.file.approved) {
      if (data.lines.containsKey(st.id)) return st.id;
    }
    return null;
  }

  /// Back to the opening view, after the tour's sample street moved the camera.
  void _restoreStartView() {
    final start = ref.read(streetMapDataProvider).valueOrNull?.file.start;
    if (start == null) return;
    _map.move(LatLng(start.lat, start.lng),
        start.zoom.clamp(kStreetMinZoom, kStreetMaxZoom));
  }

  void _tourStep(int step, StreetMapData data) {
    if (step == 0) {
      setState(() => _selected = null);
      _restoreStartView();
    } else {
      final id = _sampleStreet(data);
      if (id != null) _select(id, data, fit: true);
    }
  }

  void _endTour(String result, int step) {
    ref.read(streetTourStoreProvider).markSeen();
    ref.read(telemetryProvider).event('street_tour_end',
        <String, Object>{'result': result, 'step': step});
    setState(() {
      _tour = false;
      _selected = null;
    });
    _restoreStartView();
  }

  /// Where each tour step points, in global coordinates: the middle of the map
  /// (where streets are densest), then the street card.
  Rect? _tourTarget(String id) {
    if (id == 'card') {
      final box = _cardKey.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return null;
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.5),
      width: size.width * 0.78,
      height: 190,
    );
  }

  @override
  void dispose() {
    StreetPerf.instance.report();
    _query.dispose();
    _map.dispose();
    super.dispose();
  }

  void _select(String id, StreetMapData data, {bool fit = false}) {
    ref.read(telemetryProvider).event('street_tap', <String, Object>{
      'street_id': id,
      'target': data.street(id)?.targets.firstOrNull?.id ?? '',
    });
    setState(() => _selected = id);
    if (fit) {
      _fitTo([for (final l in data.lines[id] ?? const <List<LatLng>>[]) ...l]);
    }
  }

  /// Flies the camera to [pts], leaving room for the search bar above and
  /// the card below. The camera constraint still applies.
  void _fitTo(List<LatLng> pts) {
    if (pts.isEmpty) return;
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.fromLTRB(48, 140, 48, 280),
        maxZoom: 16,
      ),
    );
  }

  void _onTap(StreetMapData data, LatLng at) {
    final cam = _map.camera;
    GeoPt pt(LatLng p) {
      final s = cam.latLngToScreenPoint(p);
      return GeoPt(s.x, s.y);
    }

    final screen = <String, List<List<GeoPt>>>{
      for (final e in data.lines.entries)
        e.key: [
          for (final line in e.value) [for (final p in line) pt(p)],
        ],
    };
    final hit = hitTestStreet(pt(at), screen);
    if (hit == null) {
      setState(() => _selected = null);
    } else {
      _select(hit, data);
    }
  }

  Widget? _resting;
  StreetMapData? _restingData;

  Widget _restingLayer(StreetMapData data) {
    final cached = _resting;
    if (cached != null && identical(_restingData, data)) return cached;
    _restingData = data;
    return _resting = PolylineLayer(
      polylines: <Polyline>[
        for (final e in data.lines.entries)
          for (final line in e.value)
            Polyline(
              points: line,
              strokeWidth: 2.5,
              color: _kRestingStreet,
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
            ),
      ],
    );
  }

  MapOptions? _options;
  StreetMapData? _optionsData;

  /// The map's options, built once per [data]. flutter_map re-applies (and, in
  /// debug, asserts on) the options whenever the widget's options object
  /// changes, so a fresh object on every rebuild made the screen crash when a
  /// long street left the camera right at the edge of its constraint — e.g.
  /// Trần Đại Nghĩa, then returning from its person page.
  MapOptions _optionsFor(StreetMapData data, List<LatLng> selectedPts) {
    final cached = _options;
    if (cached != null && identical(_optionsData, data)) return cached;
    final start = data.file.start;
    _optionsData = data;
    return _options = MapOptions(
      backgroundColor: VSColors.lacquer,
      minZoom: kStreetMinZoom,
      maxZoom: kStreetMaxZoom,
      cameraConstraint: CameraConstraint.contain(bounds: data.bounds),
      // Open on the mapping's own start view (the city centre, close
      // enough to read the streets). With none, start with the whole
      // locked area filling the view — the one camera `contain` is
      // always satisfied by (a plain fit of the bounds would leave a
      // tall phone view poking outside them).
      initialCameraFit: start == null
          ? CameraFit.insideBounds(bounds: data.bounds)
          : null,
      // flutter_map validates the pre-layout camera against the
      // constraint too; its centre must already be inside the bounds.
      initialCenter: start == null
          ? data.bounds.center
          : LatLng(start.lat, start.lng),
      initialZoom: start == null
          ? kStreetMinZoom
          : start.zoom.clamp(kStreetMinZoom, kStreetMaxZoom),
      onMapReady: () {
        if (selectedPts.isNotEmpty) _fitTo(selectedPts);
      },
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
      ),
      onTap: (_, at) => _onTap(data, at),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final async = ref.watch(streetMapDataProvider);
    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: VSColors.gold),
        ),
        error: (_, __) => _Unavailable(lang: lang),
        data: (data) => data == null
            ? _Unavailable(lang: lang)
            : _body(context, data, lang),
      ),
    );
  }

  Widget _body(BuildContext context, StreetMapData data, Lang lang) {
    final basemapUrl = streetBasemapUrl(data.file);
    final basemap = ref.watch(streetBasemapProvider).valueOrNull;
    if (basemap != null) StreetPerf.instance.mark('map_basemap_ready');
    final selected = _selected == null ? null : data.street(_selected!);
    final selectedPts = _selected == null
        ? const <LatLng>[]
        : [
            for (final l in data.lines[_selected!] ?? const <List<LatLng>>[])
              ...l,
          ];

    return Stack(
      children: <Widget>[
        FlutterMap(
          mapController: _map,
          options: _optionsFor(data, selectedPts),
          children: <Widget>[
            if (basemap != null)
              VectorTileLayer(
                theme: _basemapTheme,
                cacheFolder: basemap.cacheFolder,
                tileProviders: basemap.providers,
                concurrency: kBasemapConcurrency,
                fileCacheTtl: kBasemapTileTtl,
              ),
            // Soft mask outside the old boundary.
            PolygonLayer(
              polygons: <Polygon>[
                Polygon(
                  points: const <LatLng>[
                    LatLng(-85, -180),
                    LatLng(-85, 180),
                    LatLng(85, 180),
                    LatLng(85, -180),
                  ],
                  holePointsList: data.boundary,
                  color: VSColors.lacquer.withValues(alpha: 0.7),
                ),
              ],
            ),
            // The history streets — the only tappable thing (M2). The resting
            // layer is one widget built once per data, so selecting a street or
            // typing in the search box doesn't rebuild ~1,300 polylines; the
            // selected street is drawn on top.
            _restingLayer(data),
            if (_selected != null)
              PolylineLayer(
                polylines: <Polyline>[
                  for (final line
                      in data.lines[_selected!] ?? const <List<LatLng>>[])
                    Polyline(
                      points: line,
                      strokeWidth: 6,
                      color: VSColors.goldBright,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                ],
              ),
            // Places to find your way by — on top so their names stay legible,
            // but they ignore touches (the gold streets are the only tappable
            // thing).
            StreetLandmarkLayer(landmarks: data.file.landmarks, lang: lang),
            // ODbL: always visible. (Our own widget rather than flutter_map's
            // SimpleAttributionWidget, whose row can't shrink on narrow phones
            // or large text scales.)
            Align(
              alignment: Alignment.bottomLeft,
              child: SafeArea(
                child: Container(
                  key: const Key('street-attribution'),
                  margin: const EdgeInsets.all(VSSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: VSColors.lacquer.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    basemapUrl.isEmpty
                        ? '© OpenStreetMap contributors'
                        : '© OpenStreetMap contributors · Protomaps',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VSType.caption.copyWith(
                      fontSize: 10.5,
                      color: VSColors.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: VSSpacing.md),
            child: Column(
              children: <Widget>[
                const SizedBox(height: VSSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    CircleIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => context.pop(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: VSSpacing.sm,
                        ),
                        child: Text(
                          lang == Lang.vi
                              ? 'Đường phố mang tên sử'
                              : 'Streets named for history',
                          textAlign: TextAlign.center,
                          style: VSType.bodySmall.copyWith(
                            color: VSColors.goldBright,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const LangToggle(),
                  ],
                ),
                const SizedBox(height: VSSpacing.sm),
                _Search(
                  controller: _query,
                  streets: data.file.approved
                      .where((s) => data.lines.containsKey(s.id))
                      .toList(),
                  lang: lang,
                  onPick: (s) {
                    _query.clear();
                    FocusScope.of(context).unfocus();
                    _select(s.id, data, fit: true);
                  },
                ),
              ],
            ),
          ),
        ),
        if (selected != null)
          Positioned(
            left: VSSpacing.md,
            right: VSSpacing.md,
            bottom: VSSpacing.xl + 24, // clear of the attribution
            child: SafeArea(
              top: false,
              child: KeyedSubtree(
                key: _cardKey,
                child: StreetCard(
                  key: ValueKey<String>(selected.id),
                  street: selected,
                  onClose: () => setState(() => _selected = null),
                ),
              ),
            ),
          ),
        // Keyed: the card above appears and disappears in this same child
        // list, and without a key the tour would be rebuilt from step 1 each
        // time (the card shifts its position).
        if (_tour)
          Positioned.fill(
            key: const ValueKey<String>('street-tour'),
            child: StreetCoachmarks(
              targetFor: _tourTarget,
              onStep: (i) => _tourStep(i, data),
              onEnd: _endTour,
            ),
          ),
      ],
    );
  }
}

/// "Tìm tên đường" — a light search over the approved streets (~100 names).
class _Search extends StatelessWidget {
  const _Search({
    required this.controller,
    required this.streets,
    required this.lang,
    required this.onPick,
  });

  final TextEditingController controller;
  final List<MappedStreet> streets;
  final Lang lang;
  final void Function(MappedStreet) onPick;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final q = normalizeName(value.text);
        final matches = q.isEmpty
            ? const <MappedStreet>[]
            : streets
                  .where((s) => normalizeName(s.name).contains(q))
                  .take(6)
                  .toList();
        return Column(
          children: <Widget>[
            Material(
              color: VSColors.lacquerRaised.withValues(alpha: 0.92),
              shape: const StadiumBorder(
                side: BorderSide(color: VSColors.gold, width: 0.6),
              ),
              child: TextField(
                key: const Key('street-search'),
                controller: controller,
                style: VSType.bodySmall,
                cursorColor: VSColors.gold,
                // A borderless field top-aligns its text; the 48px prefix icon
                // then leaves hint and input riding high. Centre them.
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: VSColors.gold,
                  ),
                  hintText: lang == Lang.vi ? 'Tìm tên đường' : 'Find a street',
                  hintStyle: VSType.bodySmall.copyWith(
                    color: VSColors.gold.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            if (matches.isNotEmpty)
              Material(
                color: VSColors.lacquerRaised.withValues(alpha: 0.96),
                child: Column(
                  children: <Widget>[
                    for (final s in matches)
                      ListTile(
                        key: Key('street-result-${s.id}'),
                        dense: true,
                        title: Text(s.name, style: VSType.bodySmall),
                        onTap: () => onPick(s),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Shown when the street data isn't there (mapping/boundary/geometry missing
/// or the geometry couldn't be fetched). Never an unbounded map.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.lang});
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(VSSpacing.md),
            child: CircleIconButton(
              icon: Icons.arrow_back,
              onTap: () => context.pop(),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(VSSpacing.xl),
              child: Text(
                lang == Lang.vi
                    ? 'Bản đồ đường phố chưa sẵn sàng. Vui lòng thử lại khi có mạng.'
                    : 'The street map isn\'t ready yet. Please try again when online.',
                textAlign: TextAlign.center,
                style: VSType.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
