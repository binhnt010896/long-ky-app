import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// A year scrubber for the territory atlas. The available snapshot [years] are
/// laid out at equal intervals (ordinal, not linear — so labels never crowd),
/// with a draggable thumb that snaps to the nearest snapshot. A pill shows the
/// current year.
class TimelineBar extends StatelessWidget {
  const TimelineBar({
    super.key,
    required this.years,
    required this.selected,
    required this.onChanged,
    this.openEnded = false,
  });

  final List<int> years;
  final int selected;
  final ValueChanged<int> onChanged;

  /// True when the *last* (largest) year in [years] is a snapshot that still
  /// holds today — e.g. the territory atlas's final snapshot covers 1977
  /// through the current chronicle. That year's label then reads as an
  /// open-ended span ("1977 – nay") rather than a single fixed year.
  final bool openEnded;

  static const double _pad = 22;
  static const double _height = 66;

  double _x(int i, double w) =>
      years.length <= 1 ? w / 2 : _pad + i / (years.length - 1) * (w - 2 * _pad);

  int _indexAt(double dx, double w) {
    if (years.length <= 1) return 0;
    final t = ((dx - _pad) / (w - 2 * _pad)).clamp(0.0, 1.0);
    return (t * (years.length - 1)).round();
  }

  int get _latestYear =>
      years.isEmpty ? 0 : years.reduce((a, b) => a > b ? a : b);

  String _label(int y) {
    final base = y < 0 ? '${-y} TCN' : '$y';
    return openEnded && y == _latestYear && y > 0 ? '$base – nay' : base;
  }

  /// A rough per-character width at the pill's bold 12px, floored at the old
  /// fixed 60px so short years ("500 TCN") don't shrink from what they were.
  double _pillWidth(int y) => (_label(y).length * 7.6 + 20).clamp(60.0, 120.0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final selIdx = years.indexOf(selected).clamp(0, years.length - 1);
        void pick(double dx) => onChanged(years[_indexAt(dx, w)]);
        // With many snapshots the labels crowd, so show only a sparse subset
        // (plus the selected one); every tick still renders.
        final labelStep = (years.length / 6).ceil().clamp(1, years.length);
        bool showLabel(int i) {
          // The selected tick's year is already named by the pill above the
          // thumb; showing it again here just collides with the pill.
          if (i == selIdx) return false;
          if ((i - selIdx).abs() < labelStep) return false;
          return i % labelStep == 0 || i == years.length - 1;
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => pick(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
          child: SizedBox(
            height: _height,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // Track.
                Positioned(
                  left: _pad,
                  right: _pad,
                  top: 34,
                  child: Container(height: 2, color: VSColors.goldBorder),
                ),
                // Ticks + year labels.
                for (var i = 0; i < years.length; i++) ...<Widget>[
                  Positioned(
                    left: _x(i, w) - 1,
                    top: 30,
                    child: Container(
                      width: 2,
                      height: 9,
                      color: i == selIdx
                          ? VSColors.goldBright
                          : VSColors.goldBorder,
                    ),
                  ),
                  if (showLabel(i))
                    Positioned(
                      left: _x(i, w) - 24,
                      top: 44,
                      width: 48,
                      child: Text(
                        _label(years[i]),
                        textAlign: TextAlign.center,
                        style: VSType.caption.copyWith(
                          fontSize: 8.5,
                          color: i == selIdx ? VSColors.gold : VSColors.inkMuted,
                          fontWeight:
                              i == selIdx ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
                // Thumb.
                Positioned(
                  left: _x(selIdx, w) - 8,
                  top: 27,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: VSColors.goldSheen,
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: VSColors.goldGlow, blurRadius: 8),
                      ],
                    ),
                  ),
                ),
                // Current-year pill. Sized to its text (an open-ended span
                // like "1977 – nay" is longer than a bare year) so it never
                // wraps to a second line.
                Positioned(
                  left: (_x(selIdx, w) - _pillWidth(selected) / 2)
                      .clamp(0.0, w - _pillWidth(selected)),
                  top: 2,
                  child: Container(
                    width: _pillWidth(selected),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB0623A),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      _label(selected),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: VSType.label.copyWith(
                          color: VSColors.inkPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
