import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../widgets/circle_icon_button.dart';
import '../../widgets/territory_map.dart';
import '../../widgets/timeline_bar.dart';
import 'territory_atlas_data.dart';
import 'territory_atlas_model.dart';

/// The territory atlas: an interactive map of Vietnam and its neighbours across
/// history. A timeline scrubber picks the year; the map redraws with that year's
/// polities (real simplified borders). Tap any region, island, or neighbour to
/// see who held it.
class TerritoryMapDemoScreen extends StatefulWidget {
  const TerritoryMapDemoScreen({super.key, this.initialYear});

  final int? initialYear;

  /// The snapshot year nearest [year] (used to map an era's date onto the atlas).
  static int nearestYear(int year) {
    var best = kAtlas.first.year;
    var bestD = (best - year).abs();
    for (final a in kAtlas) {
      final d = (a.year - year).abs();
      if (d < bestD) {
        bestD = d;
        best = a.year;
      }
    }
    return best;
  }

  @override
  State<TerritoryMapDemoScreen> createState() => _TerritoryMapDemoScreenState();
}

class _TerritoryMapDemoScreenState extends State<TerritoryMapDemoScreen> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = TerritoryMapDemoScreen.nearestYear(
        widget.initialYear ?? kAtlas.first.year);
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
    final snap = kAtlas.firstWhere((a) => a.year == _year, orElse: () => kAtlas.first);
    final isModern = _year == kAtlas.last.year;
    final forces = <TerritoryRegion>[
      for (final r in snap.regions) if (r.bright) _toRegion(r),
    ];
    final neighbours = <TerritoryRegion>[
      for (final r in snap.regions) if (!r.bright) _toRegion(r),
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
                        Text('Việt Nam qua các thời kỳ',
                            style: VSType.title.copyWith(fontSize: 18)),
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
                'Kéo thanh thời gian để đổi năm · chạm một vùng để xem thế lực. '
                'Nét đứt là ranh giới Việt Nam ngày nay.',
                style: TextStyle(color: VSColors.inkMuted, fontSize: 12.5),
              ),
            ),
            Expanded(
              child: TerritoryMap(
                key: ValueKey<int>(_year),
                forces: forces,
                neighbours: neighbours,
                islandLands: islandLands,
                mapAspect: snap.mapAspect,
                boundary: snap.boundary,
                boundaryLabel: snap.boundaryLabel,
                // The present-day outline, dashed, on every historical year —
                // hidden only on the modern year where it would be redundant.
                reference: isModern ? null : kModernVietnam,
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
                years: <int>[for (final a in kAtlas) a.year],
                selected: _year,
                onChanged: (y) => setState(() => _year = y),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
