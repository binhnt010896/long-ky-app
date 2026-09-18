import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// The recurring circular chrome button — a hairline ring around an icon.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.icon,
    required this.onTap,
    this.size = 38,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: VSColors.lacquer.withValues(alpha: 0.4),
          border: Border.all(color: VSColors.inkPrimary.withValues(alpha: 0.28)),
        ),
        child: Icon(icon, size: size * 0.42, color: VSColors.inkPrimary),
      ),
    );
  }
}
