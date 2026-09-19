import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/widgets/timeline_bar.dart';

Future<int?> _pump(WidgetTester tester, int selected) async {
  int? picked;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: TimelineBar(
              years: const <int>[200, 900, 1650, 2010],
              selected: selected,
              onChanged: (y) => picked = y,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  testWidgets('renders the year labels and current-year pill', (tester) async {
    await _pump(tester, 1650);
    expect(find.text('200'), findsWidgets);
    expect(find.text('2010'), findsWidgets);
    expect(find.text('1650'), findsWidgets); // tick + pill
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap fires onChanged with the nearest year', (tester) async {
    int? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: TimelineBar(
                years: const <int>[200, 900, 1650, 2010],
                selected: 200,
                onChanged: (y) => picked = y,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final box = tester.getRect(find.byType(TimelineBar));
    await tester.tapAt(Offset(box.right - 4, box.top + 34));
    expect(picked, 2010);
    await tester.tapAt(Offset(box.left + 4, box.top + 34));
    expect(picked, 200);
  });
}
