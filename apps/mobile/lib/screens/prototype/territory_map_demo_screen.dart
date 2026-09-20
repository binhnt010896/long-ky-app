import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../widgets/circle_icon_button.dart';
import '../../widgets/territory_map.dart';
import '../../widgets/timeline_bar.dart';
import 'territory_atlas_data.dart';
import 'territory_atlas_model.dart';

/// The territory atlas: an interactive map of Vietnam and its neighbours across
/// history. A timeline scrubber picks the dynasty; the map redraws with that
/// era's polities (real coastlines, authored borders). Tap any region, claim,
/// island, or neighbour to see who held it. Opened for a specific era via
/// `?era=<slug>`, or from the start when none is given.
class TerritoryMapDemoScreen extends StatefulWidget {
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
  State<TerritoryMapDemoScreen> createState() => _TerritoryMapDemoScreenState();
}

class _TerritoryMapDemoScreenState extends State<TerritoryMapDemoScreen> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = TerritoryMapDemoScreen.snapshotIndexForEra(widget.initialEra);
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

  TerritoryRegion _toRegion(AtlasRegion r) => TerritoryRegion(
        id: r.id,
        name: r.name,
        subtitle: r.subtitle,
        color: Color(r.color),
        rings: r.rings,
        labelAt: r.labelAt,
      );

  @override
  Widget build(BuildContext context) {
    final snap = kAtlas[_index];
    final forces = <TerritoryRegion>[
      for (final r in snap.regions)
        if (r.role == AtlasRole.core || r.role == AtlasRole.rival) _toRegion(r),
    ];
    final claims = <TerritoryRegion>[
      for (final r in snap.regions)
        if (r.role == AtlasRole.protectorate) _toRegion(r),
    ];
    final neighbours = <TerritoryRegion>[
      for (final r in snap.regions)
        if (r.role == AtlasRole.neighbour) _toRegion(r),
    ];
    const islandGreen = Color(0xFF4F7A70);
    final islandLands = <TerritoryRegion>[
      TerritoryRegion(
        id: 'phu-quoc',
        name: 'Phú Quốc',
        subtitle: 'Đảo của Việt Nam',
        color: islandGreen,
        rings: kPhuQuoc,
        labelAt: _centroid(kPhuQuoc),
      ),
      TerritoryRegion(
        id: 'con-dao',
        name: 'Côn Đảo',
        subtitle: 'Đảo của Việt Nam',
        color: islandGreen,
        rings: kConDao,
        labelAt: _centroid(kConDao),
      ),
    ];

    return Scaffold(
      backgroundColor: VSColors.lacquer,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  VSSpacing.xl, VSSpacing.sm, VSSpacing.xl, 0),
              child: Row(
                children: <Widget>[
                  Builder(
                    builder: (context) => CircleIconButton(
                      icon: Icons.arrow_back,
                      onTap: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                    ),
                  ),
                  const SizedBox(width: VSSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'BẢN ĐỒ LÃNH THỔ',
                          style: VSType.overline.copyWith(
                            color: VSColors.goldBright,
                            letterSpacing: VSType.track(0.3, 10),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(snap.title, style: VSType.title.copyWith(fontSize: 18)),
                        if (snap.subtitle != null)
                          Text(snap.subtitle!,
                              style: VSType.caption.copyWith(
                                  color: VSColors.gold, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                  VSSpacing.xl, 6, VSSpacing.xl, VSSpacing.sm),
              child: Text(
                'Kéo thanh thời gian để đổi thời kỳ · chạm một vùng để xem thế lực. '
                'Nét đứt là ranh giới Việt Nam ngày nay.',
                style: TextStyle(color: VSColors.inkMuted, fontSize: 12.5),
              ),
            ),
            Expanded(
              child: TerritoryMap(
                key: ValueKey<int>(_index),
                forces: forces,
                neighbours: neighbours,
                claims: claims,
                islandLands: islandLands,
                mapAspect: snap.mapAspect,
                boundary: snap.boundary,
                boundaryLabel: snap.boundaryLabel,
                reference: kModernVietnam,
                referenceLabel: 'Ranh giới ngày nay',
                islands: const <TerritoryIslands>[
                  TerritoryIslands(
                    name: 'Hoàng Sa',
                    subtitle: 'Quần đảo của Việt Nam',
                    center: Offset(0.722, 0.395),
                  ),
                  TerritoryIslands(
                    name: 'Trường Sa',
                    subtitle: 'Quần đảo của Việt Nam',
                    center: Offset(0.833, 0.758),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  VSSpacing.md, 0, VSSpacing.md, VSSpacing.sm),
              child: TimelineBar(
                years: <int>[for (final s in kAtlas) s.anchorYear],
                selected: snap.anchorYear,
                onChanged: (y) {
                  final i = kAtlas.indexWhere((s) => s.anchorYear == y);
                  if (i >= 0) setState(() => _index = i);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
