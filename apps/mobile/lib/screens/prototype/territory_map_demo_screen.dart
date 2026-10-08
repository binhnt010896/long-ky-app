import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../state/providers.dart';
import '../../state/tour_store.dart';
import '../../telemetry/telemetry.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/map_coachmarks.dart';
import '../../widgets/territory_map.dart';
import '../../widgets/timeline_bar.dart';
import 'territory_atlas_data.dart';
import 'territory_atlas_model.dart';

/// The territory atlas: an interactive map of Vietnam and its neighbours across
/// history. A timeline scrubber picks the dynasty; the map redraws with that
/// era's polities (real coastlines, authored borders). Tap any region, claim,
/// island, or neighbour to see who held it. Opened for a specific era via
/// `?era=<slug>`, or from the start when none is given.
class TerritoryMapDemoScreen extends ConsumerStatefulWidget {
  const TerritoryMapDemoScreen({super.key, this.initialEra});

  /// The era slug to open on (its dynasty snapshot). Null → the first snapshot.
  final String? initialEra;

  /// Index of the snapshot covering [era], or 0 if none/unknown.
  static int snapshotIndexForEra(String? era) {
    if (era == null) return 0;
    final i = kAtlas.indexWhere((s) => s.eras.contains(era));
    return i < 0 ? 0 : i;
  }

  @override
  ConsumerState<TerritoryMapDemoScreen> createState() =>
      _TerritoryMapDemoScreenState();
}

class _TerritoryMapDemoScreenState
    extends ConsumerState<TerritoryMapDemoScreen> {
  late int _index;
  Timer? _eraChangeDebounce;

  /// The first-visit tour: shown once, stored as seen when ended.
  bool _tour = false;
  final GlobalKey _mapKey = GlobalKey();
  final GlobalKey _barKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _index = TerritoryMapDemoScreen.snapshotIndexForEra(widget.initialEra);
    _maybeStartTour();
  }

  Future<void> _maybeStartTour() async {
    if (await ref.read(atlasTourStoreProvider).seen() || !mounted) return;
    // Let the map paint first; the tour is a hint, not a gate.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _tour = true);
  }

  void _endTour(String result, int step) {
    ref.read(atlasTourStoreProvider).markSeen();
    ref.read(telemetryProvider).event('atlas_tour_end', <String, Object>{
      'result': result,
      'step': step,
    });
    setState(() => _tour = false);
  }

  /// Where each tour step points, in global coordinates: the middle of the map
  /// (a spotlight over the whole map would leave no room for the tour card),
  /// then the timeline scrubber under it.
  Rect? _tourTarget(String id) {
    final box = (id == 'timeline' ? _barKey : _mapKey).currentContext
        ?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (id == 'timeline') return rect;
    return Rect.fromCenter(
      center: rect.center,
      width: rect.width * 0.78,
      height: rect.height * 0.34,
    );
  }

  @override
  void dispose() {
    _eraChangeDebounce?.cancel();
    super.dispose();
  }

  /// Debounced so dragging the scrubber through several snapshots only counts
  /// the one it settles on.
  void _onSnapshotSettled(AtlasSnapshot snap) {
    if (snap.eras.isEmpty) return;
    _eraChangeDebounce?.cancel();
    _eraChangeDebounce = Timer(const Duration(milliseconds: 600), () {
      ref.read(telemetryProvider).event('atlas_era_change', <String, Object>{
        'era_slug': snap.eras.first,
      });
    });
  }

  Offset _centroid(List<List<Offset>> rings) {
    var sx = 0.0, sy = 0.0, n = 0;
    for (final r in rings) {
      for (final p in r) {
        sx += p.dx;
        sy += p.dy;
        n++;
      }
    }
    return n == 0 ? Offset.zero : Offset(sx / n, sy / n);
  }

  TerritoryRegion _toRegion(AtlasRegion r, Lang lang) => TerritoryRegion(
    id: r.id,
    name: r.name.resolve(lang),
    subtitle: r.subtitle?.resolve(lang),
    color: Color(r.color),
    rings: r.rings,
    labelAt: r.labelAt,
  );

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final en = lang == Lang.en;
    final snap = kAtlas[_index];
    final forces = <TerritoryRegion>[
      for (final r in snap.regions)
        if (r.role == AtlasRole.core || r.role == AtlasRole.rival)
          _toRegion(r, lang),
    ];
    final claims = <TerritoryRegion>[
      for (final r in snap.regions)
        if (r.role == AtlasRole.protectorate) _toRegion(r, lang),
    ];
    final neighbours = <TerritoryRegion>[
      for (final r in snap.regions)
        if (r.role == AtlasRole.neighbour) _toRegion(r, lang),
    ];
    const islandGreen = Color(0xFF4F7A70);
    final islandOfVietnam = en ? 'Island of Vietnam' : 'Đảo của Việt Nam';
    final islandLands = <TerritoryRegion>[
      TerritoryRegion(
        id: 'phu-quoc',
        name: 'Phú Quốc',
        subtitle: islandOfVietnam,
        color: islandGreen,
        rings: kPhuQuoc,
        labelAt: _centroid(kPhuQuoc),
      ),
      TerritoryRegion(
        id: 'con-dao',
        name: 'Côn Đảo',
        subtitle: islandOfVietnam,
        color: islandGreen,
        rings: kConDao,
        labelAt: _centroid(kConDao),
      ),
    ];

    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    VSSpacing.xl,
                    VSSpacing.sm,
                    VSSpacing.xl,
                    0,
                  ),
                  child: Row(
                    children: <Widget>[
                      Builder(
                        builder: (context) => CircleIconButton(
                          icon: Icons.arrow_back,
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go('/'),
                        ),
                      ),
                      const SizedBox(width: VSSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              en ? 'TERRITORY ATLAS' : 'BẢN ĐỒ LÃNH THỔ',
                              style: VSType.overline.copyWith(
                                color: VSColors.goldBright,
                                letterSpacing: VSType.track(0.3, 10),
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              snap.title.resolve(lang),
                              style: VSType.title.copyWith(fontSize: 18),
                            ),
                            if (snap.subtitle != null)
                              Text(
                                snap.subtitle!.resolve(lang),
                                style: VSType.caption.copyWith(
                                  color: VSColors.gold,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    VSSpacing.xl,
                    6,
                    VSSpacing.xl,
                    VSSpacing.sm,
                  ),
                  child: Text(
                    en
                        ? 'Drag the timeline to change period · tap a region to see who '
                              'held it. The dashed outline is present-day Vietnam.'
                        : 'Kéo thanh thời gian để đổi thời kỳ · chạm một vùng để xem thế lực. '
                              'Nét đứt là ranh giới Việt Nam ngày nay.',
                    style: const TextStyle(
                      color: VSColors.inkMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: _mapKey,
                    child: TerritoryMap(
                      key: ValueKey<int>(_index),
                      forces: forces,
                      neighbours: neighbours,
                      claims: claims,
                      islandLands: islandLands,
                      mapAspect: snap.mapAspect,
                      boundary: snap.boundary,
                      boundaryLabel: snap.boundaryLabel?.resolve(lang),
                      reference: kModernVietnam,
                      referenceLabel: en
                          ? 'Present-day border'
                          : 'Ranh giới ngày nay',
                      protectorateSuffix: en ? ' (protectorate)' : ' (bảo hộ)',
                      islands: <TerritoryIslands>[
                        TerritoryIslands(
                          name: 'Hoàng Sa',
                          subtitle: en
                              ? 'Archipelago of Vietnam'
                              : 'Quần đảo của Việt Nam',
                          center: const Offset(0.722, 0.395),
                        ),
                        TerritoryIslands(
                          name: 'Trường Sa',
                          subtitle: en
                              ? 'Archipelago of Vietnam'
                              : 'Quần đảo của Việt Nam',
                          center: const Offset(0.833, 0.758),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    VSSpacing.md,
                    0,
                    VSSpacing.md,
                    VSSpacing.sm,
                  ),
                  child: KeyedSubtree(
                    key: _barKey,
                    child: TimelineBar(
                      years: <int>[for (final s in kAtlas) s.anchorYear],
                      selected: snap.anchorYear,
                      lang: lang,
                      // The last snapshot ("thong-nhat", 1977) is the territory as
                      // it stands through the current chronicle, not a fixed year.
                      openEnded: true,
                      onChanged: (y) {
                        final i = kAtlas.indexWhere((s) => s.anchorYear == y);
                        if (i >= 0) {
                          setState(() => _index = i);
                          _onSnapshotSettled(kAtlas[i]);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_tour)
            Positioned.fill(
              key: const ValueKey<String>('atlas-tour'),
              child: MapCoachmarks(
                steps: kAtlasTourSteps,
                keyPrefix: 'atlas',
                nameVi: 'bản đồ lãnh thổ',
                nameEn: 'Territory atlas',
                targetFor: _tourTarget,
                onStep: (_) {},
                onEnd: _endTour,
              ),
            ),
        ],
      ),
    );
  }
}
