import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// The smallest a tap target should be (logical px) — the shared floor for
/// chrome buttons and text links.
const double kMinTapTarget = 44;

/// A tappable region that answers the finger: it dims while pressed, reads as
/// one button to a screen reader, and can pad itself out to [minSize] so a
/// small glyph or a line of text is still easy to hit.
///
/// Drop-in for the app's `GestureDetector(onTap: …, child: …)` pattern.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.onTap,
    required this.child,
    this.behavior = HitTestBehavior.opaque,
    this.semanticLabel,
    this.selected,
    this.minSize,
    this.alignment = Alignment.center,
    this.pressedOpacity = 0.55,
    this.haptic = false,
    super.key,
  });

  /// Null disables the control (no feedback, announced as disabled).
  final VoidCallback? onTap;
  final Widget child;
  final HitTestBehavior behavior;

  /// Spoken instead of the child's own text. Give one to any control that is
  /// only an icon or a picture.
  final String? semanticLabel;

  /// Announced as selected / not selected (a segment, a chip). Null = neither.
  final bool? selected;

  /// Grows the hit area to at least this square, keeping [child] at its own
  /// size and placed by [alignment].
  final double? minSize;
  final AlignmentGeometry alignment;

  final double pressedOpacity;

  /// A light selection tick on tap — for controls that change a value in place.
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget child = AnimatedOpacity(
      opacity: _down && enabled ? widget.pressedOpacity : 1,
      // Dim at once, recover a touch slower — a quick tap still shows.
      duration: Duration(milliseconds: _down ? 40 : 160),
      child: widget.child,
    );
    final min = widget.minSize;
    if (min != null) {
      child = ConstrainedBox(
        constraints: BoxConstraints(minWidth: min, minHeight: min),
        child: Align(
          alignment: widget.alignment,
          widthFactor: 1,
          heightFactor: 1,
          child: child,
        ),
      );
    }
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: widget.selected,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: widget.behavior,
          onTapDown: enabled ? (_) => _set(true) : null,
          onTapUp: enabled ? (_) => _set(false) : null,
          onTapCancel: enabled ? () => _set(false) : null,
          onTap: enabled
              ? () {
                  if (widget.haptic) HapticFeedback.selectionClick();
                  widget.onTap!();
                }
              : null,
          child: child,
        ),
      ),
    );
  }
}
