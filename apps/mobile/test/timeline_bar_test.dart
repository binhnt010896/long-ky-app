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
    // The selected year's tick label is suppressed (the pill already names
    // it, directly above the thumb), so it's the pill alone.
    expect(find.text('1650'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('openEnded reads the latest year as a span, not a fixed year',
      (tester) async {
    int? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: TimelineBar(
                years: const <int>[200, 900, 1650, 2010],
                selected: 2010,
                openEnded: true,
                onChanged: (y) => picked = y,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2010 – nay'), findsOneWidget);
    expect(find.text('2010'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(picked, isNull); // sanity: no tap fired yet
  });

  testWidgets("the pill doesn't wrap for a long open-ended label",
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: TimelineBar(
                years: const <int>[-500, 900, 1650, 1977],
                selected: 1977,
                openEnded: true,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text('1977 – nay'));
    expect(text.maxLines, 1);
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
