import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

import 'new_dot.dart';

/// The recurring circular chrome button — a hairline ring around an icon.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.icon,
    required this.onTap,
    this.size = 38,
    this.showNew = false,
    this.newDotKey,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  /// A small red dot on the top-right corner: the reader hasn't opened this yet.
  final bool showNew;

  /// Optional key for the dot, so tests can find it.
  final Key? newDotKey;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VSColors.lacquer.withValues(alpha: 0.4),
              border: Border.all(
                color: VSColors.inkPrimary.withValues(alpha: 0.28),
              ),
            ),
            child: Icon(icon, size: size * 0.42, color: VSColors.inkPrimary),
          ),
          if (showNew)
            Positioned(top: -1, right: -1, child: NewDot(key: newDotKey)),
        ],
      ),
    );
  }
}
