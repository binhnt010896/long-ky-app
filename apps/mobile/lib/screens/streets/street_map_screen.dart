import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

import '../../state/providers.dart';
import '../../telemetry/telemetry.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/lang_toggle.dart';
import 'street_basemap.dart';
import 'street_card.dart';
import 'street_data.dart';

/// Minimum zoom of the street map. Together with the camera constraint it
/// keeps the open sea and the island chains out of frame (sovereignty guard).
const double kStreetMinZoom = 10;
const double kStreetMaxZoom = 17;

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
  final TextEditingController _query = TextEditingController();
  Future<PmTilesVectorTileProvider>? _tiles;
  String _tilesUrl = '';

  // Built ONCE. The vector layer restarts its tile loading whenever the theme
  // or the provider map it is handed changes identity, so creating either in
  // build() (which runs on every selection, search keystroke and data refresh)
  // would keep it from ever finishing a first paint.
  final vtr.Theme _basemapTheme = buildStreetBasemapTheme();
  TileProviders? _tileProviders;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialStreetId;
  }

  /// The tile provider for [url], created once per address (the mapping — and
  /// so the address — only arrives with the data, after the first frame).
  Future<PmTilesVectorTileProvider>? _tilesFor(String url) {
    if (url.isEmpty) return null;
    if (url != _tilesUrl) {
      _tilesUrl = url;
      _tileProviders = null;
      _tiles = PmTilesVectorTileProvider.fromSource(url);
    }
    return _tiles;
  }

  @override
  void dispose() {
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
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: const EdgeInsets.fromLTRB(48, 140, 48, 280),
      maxZoom: 16,
    ));
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

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final async = ref.watch(streetMapDataProvider);
    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: VSColors.gold)),
        error: (_, __) => _Unavailable(lang: lang),
        data: (data) =>
            data == null ? _Unavailable(lang: lang) : _body(context, data, lang),
      ),
    );
  }

  Widget _body(BuildContext context, StreetMapData data, Lang lang) {
    final basemapUrl = streetBasemapUrl(data.file);
    final tiles = _tilesFor(basemapUrl);
    final selected = _selected == null ? null : data.street(_selected!);
    final selectedPts = _selected == null
        ? const <LatLng>[]
        : [for (final l in data.lines[_selected!] ?? const <List<LatLng>>[]) ...l];

    return Stack(
      children: <Widget>[
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            backgroundColor: VSColors.lacquer,
            minZoom: kStreetMinZoom,
            maxZoom: kStreetMaxZoom,
            cameraConstraint: CameraConstraint.contain(bounds: data.bounds),
            // Start with the whole locked area filling the view — the one
            // camera `contain` is always satisfied by (a plain fit of the
            // bounds would leave a tall phone view poking outside them).
            initialCameraFit: CameraFit.insideBounds(bounds: data.bounds),
            // flutter_map validates the pre-layout camera against the
            // constraint too; its centre must already be inside the bounds.
            initialCenter: data.bounds.center,
            initialZoom: kStreetMinZoom,
            onMapReady: () {
              if (selectedPts.isNotEmpty) _fitTo(selectedPts);
            },
            interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onTap: (_, at) => _onTap(data, at),
          ),
          children: <Widget>[
            if (tiles != null)
              FutureBuilder<PmTilesVectorTileProvider>(
                future: tiles,
                builder: (context, snap) {
                  final p = snap.data;
                  if (snap.hasError) {
                    // The map still works without a base map; just say why.
                    debugPrint('street basemap unavailable: ${snap.error}');
                  }
                  if (p == null) return const SizedBox.shrink();
                  return VectorTileLayer(
                    theme: _basemapTheme,
                    tileProviders: _tileProviders ??=
                        TileProviders(<String, VectorTileProvider>{
                      'protomaps': p,
                    }),
                  );
                },
              ),
            // Soft mask outside the old boundary.
            PolygonLayer(polygons: <Polygon>[
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
            ]),
            // The history streets — the only tappable thing (M2).
            PolylineLayer(polylines: <Polyline>[
              for (final e in data.lines.entries)
                if (e.key != _selected)
                  for (final line in e.value)
                    Polyline(
                        points: line,
                        strokeWidth: 3,
                        color: VSColors.gold,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round),
              if (_selected != null)
                for (final line in data.lines[_selected!] ?? const <List<LatLng>>[])
                  Polyline(
                      points: line,
                      strokeWidth: 6,
                      color: VSColors.goldBright,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round),
            ]),
            // ODbL: always visible. (Our own widget rather than flutter_map's
            // SimpleAttributionWidget, whose row can't shrink on narrow phones
            // or large text scales.)
            Align(
              alignment: Alignment.bottomLeft,
              child: SafeArea(
                child: Container(
                  key: const Key('street-attribution'),
                  margin: const EdgeInsets.all(VSSpacing.sm),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    style: VSType.caption
                        .copyWith(fontSize: 10.5, color: VSColors.inkMuted),
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
                        icon: Icons.arrow_back, onTap: () => context.pop()),
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: VSSpacing.sm),
                        child: Text(
                          lang == Lang.vi
                              ? 'Đường phố mang tên sử'
                              : 'Streets named for history',
                          textAlign: TextAlign.center,
                          style: VSType.bodySmall.copyWith(
                              color: VSColors.goldBright,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
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
              child: StreetCard(
                key: ValueKey<String>(selected.id),
                street: selected,
                onClose: () => setState(() => _selected = null),
              ),
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
                  side: BorderSide(color: VSColors.gold, width: 0.6)),
              child: TextField(
                key: const Key('street-search'),
                controller: controller,
                style: VSType.bodySmall,
                cursorColor: VSColors.gold,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: VSColors.gold),
                  hintText: lang == Lang.vi ? 'Tìm tên đường' : 'Find a street',
                  hintStyle: VSType.bodySmall
                      .copyWith(color: VSColors.gold.withValues(alpha: 0.6)),
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
                icon: Icons.arrow_back, onTap: () => context.pop()),
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
