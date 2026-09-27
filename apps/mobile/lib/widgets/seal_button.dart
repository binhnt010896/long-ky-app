import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// The Long Ký seal as a small square button — the door into the Sảnh. Square
/// on purpose, so it reads as the brand beside the round icon buttons.
class SealButton extends StatelessWidget {
  const SealButton({
    required this.onTap,
    this.size = 34,
    this.lang = Lang.vi,
    super.key,
  });

  static const String asset = 'assets/brand/long-ky-logo.png';

  final VoidCallback onTap;
  final double size;

  /// Drives only the screen-reader label — "Sảnh Long Ký" is the brand name
  /// and stays on-screen in both languages.
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: lang == Lang.en ? 'Long Ký hall' : 'Sảnh Long Ký',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: VSColors.goldBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: VSColors.goldGlow.withValues(alpha: 0.25),
                blurRadius: 8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset(
              asset,
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}
