import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// One occupying force on a [TerritoryMap]: a name (already localized by the
/// caller), an optional leader/subtitle, a colour, and the region it holds
/// expressed as normalized polygon points (x,y each 0..1 within the map box,
/// y increasing downward). The widget scales the points to the laid-out size,
/// so the same shape drives both the painting and the tap hit-testing.
@immutable
class TerritoryForce {
  const TerritoryForce({
    required this.id,
    required this.name,
    required this.color,
    required this.region,
    this.leader,
  });

  final String id;
  final String name;
  final String? leader;
  final Color color;
  final List<Offset> region;
}

/// A small offshore island group that can be tapped to reveal which force
/// administered it (e.g. Hoàng Sa / Trường Sa under the Nguyễn).
@immutable
class TerritoryIslands {
  const TerritoryIslands({
    required this.name,
    required this.center,
    required this.forceId,
    this.radius = 0.055,
  });

  final String name;
  final Offset center; // normalized 0..1
  final String forceId; // which force administers it
  final double radius; // normalized (of the shorter side) tap/enclosure radius
}

/// An interactive, stylized territory map. Tapping a force's region (or an
/// island group) reveals who holds it. Deliberately *not* survey-accurate — the
/// silhouette is a recognizable stylization drawn from normalized points, in
/// the app's lacquer palette, so it reads as part of the experience rather than
/// a foreign basemap.
class TerritoryMap extends StatefulWidget {
  const TerritoryMap({
    super.key,
    required this.forces,
    this.boundary,
    this.boundaryLabel,
    this.islands = const <TerritoryIslands>[],
  });

  final List<TerritoryForce> forces;

  /// Two normalized points naming the dividing line (e.g. the Gianh River).
  final List<Offset>? boundary;
  final String? boundaryLabel;
  final List<TerritoryIslands> islands;

  @override
  State<TerritoryMap> createState() => _TerritoryMapState();
}

class _TerritoryMapState extends State<TerritoryMap> {
  String? _selectedId;
  bool _selectedIsIslands = false;

  TerritoryForce _forceById(String id) =>
      widget.forces.firstWhere((f) => f.id == id);

  Path _regionPath(TerritoryForce f, Size size) => _polyPath(f.region, size);

  void _handleTap(Offset p, Size size) {
    // Islands sit on top of the mainland fills, so test them first.
    for (final isl in widget.islands) {
      final c = Offset(isl.center.dx * size.width, isl.center.dy * size.height);
      final r = isl.radius * size.shortestSide;
      if ((p - c).distance <= r * 1.4) {
        setState(() {
          _selectedId = isl.forceId;
          _selectedIsIslands = true;
        });
        return;
      }
    }
    for (final f in widget.forces) {
      if (_regionPath(f, size).contains(p)) {
        setState(() {
          _selectedId = f.id;
          _selectedIsIslands = false;
        });
        return;
      }
    }
    setState(() => _selectedId = null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final selected = _selectedId;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _handleTap(d.localPosition, size),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CustomPaint(
                size: size,
                painter: _TerritoryPainter(
                  forces: widget.forces,
                  boundary: widget.boundary,
                  boundaryLabel: widget.boundaryLabel,
                  islands: widget.islands,
                  selectedId: selected,
                  selectedIsIslands: _selectedIsIslands,
                ),
              ),
              _Legend(forces: widget.forces, selectedId: selected),
              Align(
                alignment: Alignment.bottomCenter,
                child: _InfoCard(
                  selection: selected == null
                      ? null
                      : _CardData(
                          force: _forceById(selected),
                          islands: _selectedIsIslands
                              ? widget.islands
                                  .firstWhere((i) => i.forceId == selected)
                                  .name
                              : null,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────── painting ───────────────────────────

class _TerritoryPainter extends CustomPainter {
  _TerritoryPainter({
    required this.forces,
    required this.boundary,
    required this.boundaryLabel,
    required this.islands,
    required this.selectedId,
    required this.selectedIsIslands,
  });

  final List<TerritoryForce> forces;
  final List<Offset>? boundary;
  final String? boundaryLabel;
  final List<TerritoryIslands> islands;
  final String? selectedId;
  final bool selectedIsIslands;

  @override
  void paint(Canvas canvas, Size size) {
    // Sea backdrop.
    final sea = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF0B1512), Color(0xFF0A0F0E)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sea);

    // Each force's region.
    for (final f in forces) {
      final path = _polyPath(f.region, size);
      final isSel = f.id == selectedId && !selectedIsIslands;
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = f.color.withValues(alpha: isSel ? 0.92 : 0.66);
      canvas.drawPath(path, fill);
      // Subtle inner sheen so the fill doesn't read flat.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Colors.white.withValues(alpha: isSel ? 0.10 : 0.05),
              Colors.transparent,
            ],
          ).createShader(path.getBounds()),
      );
      // Coastline.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSel ? 2.4 : 1.2
          ..color = isSel ? VSColors.goldBright : VSColors.goldBorder,
      );
      if (isSel) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = VSColors.goldGlow.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }

    // Dividing line (e.g. the Gianh River).
    final b = boundary;
    if (b != null && b.length == 2) {
      final p1 = Offset(b[0].dx * size.width, b[0].dy * size.height);
      final p2 = Offset(b[1].dx * size.width, b[1].dy * size.height);
      _drawDashedLine(canvas, p1, p2,
          Paint()
            ..color = VSColors.goldBright
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round);
      if (boundaryLabel != null) {
        _text(canvas, boundaryLabel!, Offset((p1.dx + p2.dx) / 2, p1.dy - 16),
            color: VSColors.gold, size: 10.5, anchor: _Anchor.center);
      }
    }

    // Island groups.
    for (final isl in islands) {
      final c = Offset(isl.center.dx * size.width, isl.center.dy * size.height);
      final r = isl.radius * size.shortestSide;
      final force = forces.where((f) => f.id == isl.forceId);
      final tint = force.isEmpty ? VSColors.gold : force.first.color;
      final isSel = selectedIsIslands && isl.forceId == selectedId;
      // Dotted enclosure.
      _drawDottedCircle(canvas, c, r,
          VSColors.gold.withValues(alpha: isSel ? 0.9 : 0.5));
      // A little archipelago of dots.
      final dots = <Offset>[
        c.translate(-r * 0.4, -r * 0.35),
        c.translate(r * 0.1, -r * 0.5),
        c.translate(r * 0.45, -r * 0.15),
        c.translate(-r * 0.15, 0),
        c.translate(r * 0.3, r * 0.3),
        c.translate(-r * 0.35, r * 0.4),
        c.translate(0, r * 0.15),
      ];
      for (final d in dots) {
        canvas.drawCircle(
            d, isSel ? 3.0 : 2.2, Paint()..color = tint.withValues(alpha: 0.95));
      }
      _text(canvas, isl.name, c.translate(0, r + 10),
          color: VSColors.gold, size: 9.5, anchor: _Anchor.center);
    }
  }

  @override
  bool shouldRepaint(_TerritoryPainter old) =>
      old.selectedId != selectedId ||
      old.selectedIsIslands != selectedIsIslands ||
      old.forces != forces;
}

// ─────────────────────────── overlays ───────────────────────────

class _Legend extends StatelessWidget {
  const _Legend({required this.forces, required this.selectedId});
  final List<TerritoryForce> forces;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: VSSpacing.md,
      top: VSSpacing.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final f in forces)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: f.color.withValues(
                          alpha: f.id == selectedId ? 1 : 0.7),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: f.id == selectedId
                            ? VSColors.goldBright
                            : VSColors.goldBorder,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(f.name,
                      style: VSType.caption.copyWith(
                        fontSize: 11,
                        color: f.id == selectedId
                            ? VSColors.inkPrimary
                            : VSColors.inkMuted,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CardData {
  const _CardData({required this.force, this.islands});
  final TerritoryForce force;
  final String? islands;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.selection});
  final _CardData? selection;

  @override
  Widget build(BuildContext context) {
    final sel = selection;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SizeTransition(sizeFactor: anim, child: child),
      ),
      child: sel == null
          ? const SizedBox.shrink(key: ValueKey<String>('none'))
          : Container(
              key: ValueKey<String>(
                  '${sel.force.id}${sel.islands ?? ''}'),
              margin: const EdgeInsets.all(VSSpacing.md),
              padding: const EdgeInsets.symmetric(
                  horizontal: VSSpacing.lg, vertical: VSSpacing.md),
              decoration: BoxDecoration(
                color: VSColors.lacquerRaised.withValues(alpha: 0.94),
                borderRadius: VSRadii.cardAll,
                border: Border.all(color: VSColors.goldBorder),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: sel.force.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: VSSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          sel.islands == null
                              ? sel.force.name
                              : '${sel.force.name} · ${sel.islands}',
                          style: VSType.cardTitle.copyWith(fontSize: 15),
                        ),
                        if (sel.force.leader != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(sel.force.leader!,
                              style: VSType.caption.copyWith(
                                color: VSColors.gold,
                                fontSize: 11.5,
                              )),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────── helpers ───────────────────────────

Path _polyPath(List<Offset> pts, Size size) {
  final path = Path();
  for (var i = 0; i < pts.length; i++) {
    final p = Offset(pts[i].dx * size.width, pts[i].dy * size.height);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}

void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
  const dash = 7.0, gap = 5.0;
  final total = (b - a).distance;
  final dir = (b - a) / total;
  var t = 0.0;
  while (t < total) {
    final start = a + dir * t;
    final end = a + dir * (t + dash).clamp(0, total);
    canvas.drawLine(start, end, paint);
    t += dash + gap;
  }
}

void _drawDottedCircle(Canvas canvas, Offset c, double r, Color color) {
  final paint = Paint()..color = color;
  const count = 28;
  for (var i = 0; i < count; i++) {
    final a = (i / count) * 2 * math.pi;
    canvas.drawCircle(
        c + Offset(r * math.cos(a), r * math.sin(a)), 0.9, paint);
  }
}

enum _Anchor { center, left }

void _text(Canvas canvas, String text, Offset at,
    {required Color color, required double size, _Anchor anchor = _Anchor.left}) {
  final tp = TextPainter(
    text: TextSpan(
        text: text,
        style: TextStyle(
            color: color,
            fontSize: size,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w600)),
    textDirection: ui.TextDirection.ltr,
  )..layout();
  final dx = anchor == _Anchor.center ? at.dx - tp.width / 2 : at.dx;
  tp.paint(canvas, Offset(dx, at.dy));
}
