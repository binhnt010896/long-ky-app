import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// The widest the app ever lays out (logical px). Phones sit below it; every
/// tablet in portrait and small tablets in landscape too. Anything wider — a
/// big tablet in landscape, a desktop browser — gets the app centred at this
/// width on a plain lacquer ground, instead of a stretched phone layout.
const double kAppMaxWidth = 768;

/// Caps the app at [kAppMaxWidth] and centres it. Inside, [MediaQuery] reports
/// the capped width, so every screen that sizes itself from the screen width
/// (hero images, grids) lays out for 768, not for the full window.
class MaxWidthFrame extends StatelessWidget {
  const MaxWidthFrame({required this.child, this.maxWidth = kAppMaxWidth, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= maxWidth) return child;
    final width = math.min(mq.size.width, maxWidth);
    return ColoredBox(
      color: VSColors.lacquer,
      child: Center(
        child: SizedBox(
          width: width,
          height: mq.size.height,
          child: MediaQuery(
            data: mq.copyWith(size: Size(width, mq.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
