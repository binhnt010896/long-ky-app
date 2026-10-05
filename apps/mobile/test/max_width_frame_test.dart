import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/widgets/max_width_frame.dart';

Future<Size> _sizeAt(WidgetTester tester, Size window) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  late Size inner;
  late double mediaWidth;
  await tester.pumpWidget(MaterialApp(
    home: MaxWidthFrame(
      child: Builder(builder: (context) {
        mediaWidth = MediaQuery.sizeOf(context).width;
        return LayoutBuilder(builder: (context, c) {
          inner = Size(c.maxWidth, c.maxHeight);
          return const SizedBox.expand();
        });
      }),
    ),
  ));
  expect(mediaWidth, inner.width, reason: 'MediaQuery agrees with the layout');
  return inner;
}

void main() {
  testWidgets('a phone is left alone', (tester) async {
    expect(await _sizeAt(tester, const Size(390, 844)), const Size(390, 844));
  });

  testWidgets('exactly 768 is left alone', (tester) async {
    expect(await _sizeAt(tester, const Size(768, 1024)), const Size(768, 1024));
  });

  testWidgets('a wide window is capped at 768 and keeps its height', (tester) async {
    expect(await _sizeAt(tester, const Size(1280, 800)), const Size(768, 800));
    expect(await _sizeAt(tester, const Size(1024, 1366)), const Size(768, 1366));
  });
}
