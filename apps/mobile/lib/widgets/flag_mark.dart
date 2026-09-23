import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// A small painted Quốc kỳ — red field, gold five-pointed star. Painted rather
/// than an image so it stays crisp at chip sizes.
class FlagMark extends StatelessWidget {
  const FlagMark({this.width = 22, super.key});

  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: width * 2 / 3,
        child: const CustomPaint(painter: _FlagPainter()),
      );
}

class _FlagPainter extends CustomPainter {
  const _FlagPainter();

  static const Color red = Color(0xFFDA251D);
  static const Color gold = Color(0xFFFFCD00);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(1.5)),
      Paint()..color = red,
    );
    final c = size.center(Offset.zero);
    final outer = size.height * 0.34;
    final inner = outer * 0.382;
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = gold);
  }

  @override
  bool shouldRepaint(covariant _FlagPainter oldDelegate) => false;
}
