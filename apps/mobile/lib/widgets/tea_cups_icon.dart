import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// A row of 1–3 small gold line-drawn tea cups — the Sảnh's icon for each tip
/// size ("một/hai/ba chén trà"). Drawn in code, matching the plain line-icon
/// style of the Sảnh's other directory rows rather than commissioned art.
class TeaCupsIcon extends StatelessWidget {
  const TeaCupsIcon({required this.cups, this.size = 22, this.color, super.key});

  final int cups;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * (0.62 * cups + 0.38),
      height: size,
      child: CustomPaint(
        painter: _TeaCupsPainter(cups: cups, color: color ?? VSColors.gold),
      ),
    );
  }
}

class _TeaCupsPainter extends CustomPainter {
  const _TeaCupsPainter({required this.cups, required this.color});

  final int cups;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cupWidth = size.height * 0.62;
    final step = size.height * 0.62;
    for (var i = 0; i < cups; i++) {
      final left = i * step;
      _drawCup(canvas, paint, Rect.fromLTWH(left, 0, cupWidth, size.height));
    }
  }

  void _drawCup(Canvas canvas, Paint paint, Rect box) {
    // A simple saucer-cup silhouette: a trapezoid body, a rim line, a handle.
    final bodyTop = box.top + box.height * 0.28;
    final bodyBottom = box.top + box.height * 0.82;
    final bodyLeftTop = box.left + box.width * 0.12;
    final bodyRightTop = box.right - box.width * 0.34;
    final bodyLeftBottom = box.left + box.width * 0.02;
    final bodyRightBottom = box.right - box.width * 0.44;

    final body = Path()
      ..moveTo(bodyLeftTop, bodyTop)
      ..lineTo(bodyRightTop, bodyTop)
      ..lineTo(bodyRightBottom, bodyBottom)
      ..lineTo(bodyLeftBottom, bodyBottom)
      ..close();
    canvas.drawPath(body, paint);

    // Saucer.
    canvas.drawLine(
      Offset(box.left, bodyBottom + box.height * 0.06),
      Offset(box.left + box.width * 0.62, bodyBottom + box.height * 0.06),
      paint,
    );

    // Handle.
    final handle = Path()
      ..moveTo(bodyRightTop, bodyTop + box.height * 0.08)
      ..cubicTo(
        box.right, bodyTop,
        box.right, bodyBottom - box.height * 0.12,
        bodyRightBottom + box.width * 0.02, bodyBottom - box.height * 0.16,
      );
    canvas.drawPath(handle, paint);
  }

  @override
  bool shouldRepaint(covariant _TeaCupsPainter oldDelegate) =>
      oldDelegate.cups != cups || oldDelegate.color != color;
}
