import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../widgets/circle_icon_button.dart';
import '../../widgets/territory_map.dart';

/// Prototype screen for the interactive [TerritoryMap], seeded with the
/// Trịnh–Nguyễn division: tap the north (Đàng Ngoài) or south (Đàng Trong) to
/// reveal which lordship held it, or tap the Hoàng Sa / Trường Sa groups.
class TerritoryMapDemoScreen extends StatelessWidget {
  const TerritoryMapDemoScreen({super.key});

  static const _trinh = TerritoryForce(
    id: 'dang-ngoai',
    name: 'Đàng Ngoài (chúa Trịnh)',
    leader: 'Vua Lê · chúa Trịnh — Thăng Long',
    color: Color(0xFF5F6B86),
    region: <Offset>[
      Offset(0.30, 0.03),
      Offset(0.50, 0.02),
      Offset(0.62, 0.06),
      Offset(0.66, 0.14),
      Offset(0.57, 0.22),
      Offset(0.585, 0.30),
      Offset(0.60, 0.37),
      Offset(0.40, 0.37),
      Offset(0.40, 0.30),
      Offset(0.31, 0.25),
      Offset(0.21, 0.15),
      Offset(0.205, 0.09),
    ],
  );

  static const _nguyen = TerritoryForce(
    id: 'dang-trong',
    name: 'Đàng Trong (chúa Nguyễn)',
    leader: 'Chúa Nguyễn — Phú Xuân · Nam tiến',
    color: Color(0xFF4F7A70),
    region: <Offset>[
      Offset(0.40, 0.37),
      Offset(0.60, 0.37),
      Offset(0.665, 0.45),
      Offset(0.72, 0.54),
      Offset(0.68, 0.63),
      Offset(0.585, 0.71),
      Offset(0.55, 0.79),
      Offset(0.475, 0.88),
      Offset(0.40, 0.935),
      Offset(0.31, 0.885),
      Offset(0.365, 0.80),
      Offset(0.425, 0.70),
      Offset(0.44, 0.60),
      Offset(0.405, 0.50),
      Offset(0.45, 0.42),
    ],
  );

  @override
  Widget build(BuildContext context) {
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
                          'BẢN ĐỒ THẾ LỰC',
                          style: VSType.overline.copyWith(
                            color: VSColors.goldBright,
                            letterSpacing: VSType.track(0.3, 10),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Trịnh – Nguyễn phân tranh',
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
                'Chạm vào một vùng để xem thế lực chiếm giữ.',
                style: TextStyle(color: VSColors.inkMuted, fontSize: 12.5),
              ),
            ),
            const Expanded(
              child: TerritoryMap(
                forces: <TerritoryForce>[_trinh, _nguyen],
                boundary: <Offset>[Offset(0.40, 0.37), Offset(0.60, 0.37)],
                boundaryLabel: 'Sông Gianh – Lũy Thầy',
                islands: <TerritoryIslands>[
                  TerritoryIslands(
                      name: 'Hoàng Sa',
                      center: Offset(0.85, 0.45),
                      forceId: 'dang-trong'),
                  TerritoryIslands(
                      name: 'Trường Sa',
                      center: Offset(0.82, 0.68),
                      forceId: 'dang-trong'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
