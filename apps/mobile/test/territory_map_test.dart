import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/widgets/territory_map.dart';

const _north = TerritoryForce(
  id: 'north',
  name: 'Đàng Ngoài (chúa Trịnh)',
  leader: 'Vua Lê · chúa Trịnh',
  color: Color(0xFF5F6B86),
  region: <Offset>[
    Offset(0.1, 0.0),
    Offset(0.9, 0.0),
    Offset(0.9, 0.45),
    Offset(0.1, 0.45),
  ],
);

const _south = TerritoryForce(
  id: 'south',
  name: 'Đàng Trong (chúa Nguyễn)',
  leader: 'Chúa Nguyễn · Phú Xuân',
  color: Color(0xFF4F7A70),
  region: <Offset>[
    Offset(0.1, 0.55),
    Offset(0.9, 0.55),
    Offset(0.9, 1.0),
    Offset(0.1, 1.0),
  ],
);

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 400,
            child: TerritoryMap(
              forces: <TerritoryForce>[_north, _south],
              boundary: <Offset>[Offset(0.1, 0.5), Offset(0.9, 0.5)],
              boundaryLabel: 'Sông Gianh',
              islands: <TerritoryIslands>[
                TerritoryIslands(
                    name: 'Hoàng Sa',
                    center: Offset(0.5, 0.5),
                    forceId: 'south'),
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
  testWidgets('tapping a region reveals its occupying force', (tester) async {
    await _pump(tester);

    // The legend lists both forces; no info card yet (leader text is card-only).
    expect(find.text('Vua Lê · chúa Trịnh'), findsNothing);

    // Tap the northern region → Đàng Ngoài card.
    await tester.tapAt(tester.getTopLeft(find.byType(TerritoryMap)) +
        const Offset(150, 40));
    await tester.pumpAndSettle();
    expect(find.text('Vua Lê · chúa Trịnh'), findsOneWidget);
    expect(find.text('Chúa Nguyễn · Phú Xuân'), findsNothing);

    // Tap the southern region → Đàng Trong card.
    await tester.tapAt(tester.getTopLeft(find.byType(TerritoryMap)) +
        const Offset(150, 360));
    await tester.pumpAndSettle();
    expect(find.text('Chúa Nguyễn · Phú Xuân'), findsOneWidget);
    expect(find.text('Vua Lê · chúa Trịnh'), findsNothing);
  });

  testWidgets('tapping an island group attributes it to its force',
      (tester) async {
    await _pump(tester);

    // The gap between the two regions holds the Hoàng Sa group (force = south).
    await tester.tapAt(tester.getTopLeft(find.byType(TerritoryMap)) +
        const Offset(150, 200));
    await tester.pumpAndSettle();

    expect(find.text('Đàng Trong (chúa Nguyễn) · Hoàng Sa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
