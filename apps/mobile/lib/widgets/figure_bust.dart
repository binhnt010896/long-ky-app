import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Crops the bust (head + shoulders) out of a character reference sheet.
///
/// The sheets are laid out consistently — full-body left, **bust top-right**,
/// action pose bottom-right — so a fixed normalized source rect frames the bust
/// on every figure. Painted via [Canvas.drawImageRect] for an exact crop that
/// [BoxFit]/[Alignment] can't express. Fills its parent; give it a sized box.
class FigureBust extends StatefulWidget {
  const FigureBust({required this.assetKey, this.srcFraction = bust, super.key});

  final String assetKey;

  /// Normalized (left, top, right, bottom) of the region within the sheet.
  final Rect srcFraction;

  /// The bust: the top-right quadrant of the square reference sheet. Aspect
  /// (~0.88) matches the tiles so nothing is stretched.
  static const Rect bust = Rect.fromLTRB(0.55, 0.0, 0.99, 0.5);

  /// The full-body figure: the left panel of the sheet (aspect ~0.52). Give a
  /// box of the same aspect so the standing figure isn't stretched.
  static const Rect fullBody = Rect.fromLTRB(0.0, 0.0, 0.52, 1.0);

  @override
  State<FigureBust> createState() => _FigureBustState();
}

class _FigureBustState extends State<FigureBust> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(FigureBust oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetKey != widget.assetKey) _resolve();
  }

  void _resolve() {
    final provider = AssetImage(widget.assetKey);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _detach();
    _stream = stream;
    _listener = ImageStreamListener(
      (info, _) {
        if (mounted) setState(() => _image = info.image);
      },
      onError: (_, __) {
        if (mounted) setState(() => _image = null);
      },
    );
    stream.addListener(_listener!);
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: CustomPaint(
        painter: _BustPainter(image, widget.srcFraction),
        size: Size.infinite,
      ),
    );
  }
}

class _BustPainter extends CustomPainter {
  _BustPainter(this.image, this.srcFraction);

  final ui.Image image;
  final Rect srcFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final src = Rect.fromLTRB(
      srcFraction.left * w,
      srcFraction.top * h,
      srcFraction.right * w,
      srcFraction.bottom * h,
    );
    final dst = Offset.zero & size;
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_BustPainter old) =>
      old.image != image || old.srcFraction != srcFraction;
}
