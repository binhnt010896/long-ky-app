import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/widgets/territory_map.dart';

const _north = TerritoryRegion(
  id: 'north',
  name: 'Đàng Ngoài (chúa Trịnh)',
  subtitle: 'Vua Lê · chúa Trịnh',
  color: Color(0xFF5F6B86),
  rings: <List<Offset>>[
    <Offset>[Offset(0.1, 0.0), Offset(0.9, 0.0), Offset(0.9, 0.45), Offset(0.1, 0.45)],
  ],
);

const _south = TerritoryRegion(
  id: 'south',
  name: 'Đàng Trong (chúa Nguyễn)',
  subtitle: 'Chúa Nguyễn · Phú Xuân',
  color: Color(0xFF4F7A70),
  rings: <List<Offset>>[
    <Offset>[Offset(0.1, 0.55), Offset(0.9, 0.55), Offset(0.9, 1.0), Offset(0.1, 1.0)],
  ],
);

const _neighbour = TerritoryRegion(
  id: 'xiem',
  name: 'Xiêm La',
  subtitle: 'Ayutthaya',
  color: Color(0xFF8A5A4A),
  rings: <List<Offset>>[
    <Offset>[Offset(0.0, 0.0), Offset(0.08, 0.0), Offset(0.08, 1.0), Offset(0.0, 1.0)],
  ],
  labelAt: Offset(0.04, 0.5),
);

const _phuQuoc = TerritoryRegion(
  id: 'phu-quoc',
  name: 'Phú Quốc',
  subtitle: 'Đảo của Việt Nam',
  color: Color(0xFF4F7A70),
  rings: <List<Offset>>[
    <Offset>[Offset(0.72, 0.47), Offset(0.86, 0.47), Offset(0.86, 0.53), Offset(0.72, 0.53)],
  ],
  labelAt: Offset(0.79, 0.5),
);

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 400, // aspect 0.75 fits exactly → normalized == pixels
            child: TerritoryMap(
              forces: <TerritoryRegion>[_north, _south],
              neighbours: <TerritoryRegion>[_neighbour],
              islandLands: <TerritoryRegion>[_phuQuoc],
              mapAspect: 0.75,
              islands: <TerritoryIslands>[
                TerritoryIslands(
                  name: 'Hoàng Sa',
                  subtitle: 'Quần đảo của Việt Nam',
                  center: Offset(0.5, 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping a force reveals its occupying lord', (tester) async {
    await _pump(tester);
    final o = tester.getTopLeft(find.byType(TerritoryMap));

    await tester.tapAt(o + const Offset(150, 40));
    await tester.pumpAndSettle();
    expect(find.text('Vua Lê · chúa Trịnh'), findsOneWidget);

    await tester.tapAt(o + const Offset(150, 360));
    await tester.pumpAndSettle();
    expect(find.text('Chúa Nguyễn · Phú Xuân'), findsOneWidget);
    expect(find.text('Vua Lê · chúa Trịnh'), findsNothing);
  });

  testWidgets('tapping a neighbour names the era-appropriate polity',
      (tester) async {
    await _pump(tester);
    final o = tester.getTopLeft(find.byType(TerritoryMap));
    await tester.tapAt(o + const Offset(10, 200));
    await tester.pumpAndSettle();
    expect(find.text('Xiêm La'), findsWidgets);
    expect(find.text('Ayutthaya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an island group and an island land', (tester) async {
    await _pump(tester);
    final o = tester.getTopLeft(find.byType(TerritoryMap));

    // Archipelago marker in the gap.
    await tester.tapAt(o + const Offset(150, 200));
    await tester.pumpAndSettle();
    expect(find.text('Hoàng Sa'), findsWidgets);
    expect(find.text('Quần đảo của Việt Nam'), findsOneWidget);

    // Phú Quốc island land.
    await tester.tapAt(o + const Offset(240, 200));
    await tester.pumpAndSettle();
    expect(find.text('Đảo của Việt Nam'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a protectorate claim names it', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 400,
              child: TerritoryMap(
                forces: <TerritoryRegion>[_north],
                mapAspect: 0.75,
                claims: <TerritoryRegion>[
                  TerritoryRegion(
                    id: 'tran-tay',
                    name: 'Trấn Tây',
                    subtitle: 'Nguyễn bảo hộ',
                    color: Color(0xFF4F7A70),
                    rings: <List<Offset>>[
                      <Offset>[
                        Offset(0.1, 0.55),
                        Offset(0.9, 0.55),
                        Offset(0.9, 1.0),
                        Offset(0.1, 1.0),
                      ],
                    ],
                    labelAt: Offset(0.5, 0.78),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Legend shows it as a protectorate.
    expect(find.text('Trấn Tây (bảo hộ)'), findsOneWidget);

    final o = tester.getTopLeft(find.byType(TerritoryMap));
    await tester.tapAt(o + const Offset(150, 360));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn bảo hộ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reference outline renders and never steals a tap',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 400,
              child: TerritoryMap(
                forces: <TerritoryRegion>[_north, _south],
                mapAspect: 0.75,
                referenceLabel: 'Ranh giới ngày nay',
                // A big outline covering the whole map — it must stay a guide.
                reference: <List<Offset>>[
                  <Offset>[
                    Offset(0.0, 0.0),
                    Offset(1.0, 0.0),
                    Offset(1.0, 1.0),
                    Offset(0.0, 1.0),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The dashed outline is painted on the canvas (not a widget); the map must
    // render cleanly and the overlay must not intercept taps.
    expect(tester.takeException(), isNull);

    // The outline sits over the north force; tapping still selects the force.
    final o = tester.getTopLeft(find.byType(TerritoryMap));
    await tester.tapAt(o + const Offset(150, 40));
    await tester.pumpAndSettle();
    expect(find.text('Vua Lê · chúa Trịnh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
