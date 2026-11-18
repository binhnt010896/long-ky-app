import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../state/providers.dart';
import 'new_dot.dart';
import 'pressable.dart';

/// The recurring circular chrome button — a hairline ring around an icon.
///
/// The ring is drawn at [size], but the button takes up (and answers taps in)
/// at least [kMinTapTarget] square, so a 34px ring is still an easy target.
/// Every button names itself for a screen reader in the reading language.
class CircleIconButton extends ConsumerWidget {
  const CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.labelVi,
    required this.labelEn,
    this.size = 38,
    this.showNew = false,
    this.newDotKey,
    super.key,
  });

  /// The back arrow.
  const CircleIconButton.back({
    required this.onTap,
    this.size = 38,
    super.key,
  })  : icon = Icons.arrow_back,
        labelVi = 'Quay lại',
        labelEn = 'Back',
        showNew = false,
        newDotKey = null;

  /// The close cross.
  const CircleIconButton.close({
    required this.onTap,
    this.size = 38,
    super.key,
  })  : icon = Icons.close,
        labelVi = 'Đóng',
        labelEn = 'Close',
        showNew = false,
        newDotKey = null;

  final IconData icon;
  final VoidCallback onTap;
  final String labelVi;
  final String labelEn;
  final double size;

  /// A small red dot on the ring's top-right corner: the reader has never
  /// tapped this button. Spoken as "new" too, so the nudge reaches a screen
  /// reader as well.
  final bool showNew;

  /// Optional key for the dot, so tests can find it.
  final Key? newDotKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final en = ref.watch(langProvider) == Lang.en;
    final label = en ? labelEn : labelVi;
    return Pressable(
      onTap: onTap,
      semanticLabel: showNew ? '$label, ${en ? 'new' : 'mới'}' : label,
      minSize: kMinTapTarget,
      // The dot rides the ring (not the larger tap box), so it sits where the
      // eye expects a badge.
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
