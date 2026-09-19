import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// A polity on a [TerritoryMap]: a name (already localized by the caller), an
/// optional subtitle (leader / dates), a colour, and its shape as one or more
/// normalized rings (each point x,y in 0..1 within the map's projected box, y
/// increasing downward). Multiple rings support multi-part territories. The same
/// rings drive both the painting and the tap hit-testing.
@immutable
class TerritoryRegion {
  const TerritoryRegion({
    required this.id,
    required this.name,
    required this.color,
    required this.rings,
    this.subtitle,
    this.labelAt,
  });

  final String id;
  final String name;
  final String? subtitle;
  final Color color;
  final List<List<Offset>> rings;

  /// Where to draw the on-map label (normalized), for dim context neighbours.
  final Offset? labelAt;
}

/// A small offshore island group (Hoàng Sa / Trường Sa), drawn as a dotted
/// cluster and tappable to show its own label.
@immutable
class TerritoryIslands {
  const TerritoryIslands({
    required this.name,
    required this.center,
    this.subtitle,
    this.color = const Color(0xFF4F7A70),
    this.radius = 0.03,
  });

  final String name;
  final String? subtitle;
  final Offset center; // normalized 0..1
  final Color color;
  final double radius;
}

/// An interactive, historically-shaped territory map. [forces] are the bright,
/// legend-listed polities in focus; [neighbours] are dim context polities
/// labelled on the map. Tapping any region (or an island group) reveals who
/// held it. Geometry is real (simplified historical borders) but rendered in the
/// app's lacquer palette. [mapAspect] is the width/height of the projected box,
/// so the map fits without distortion.
class TerritoryMap extends StatefulWidget {
  const TerritoryMap({
    super.key,
    required this.forces,
    required this.mapAspect,
    this.neighbours = const <TerritoryRegion>[],
    this.islandLands = const <TerritoryRegion>[],
    this.boundary,
    this.boundaryLabel,
    this.islands = const <TerritoryIslands>[],
    this.reference,
    this.referenceLabel,
  });

  final List<TerritoryRegion> forces;
  final List<TerritoryRegion> neighbours;

  /// Small filled island territories (Phú Quốc, Côn Đảo…): drawn bright like
  /// forces but kept out of the legend, and tappable.
  final List<TerritoryRegion> islandLands;
  final double mapAspect;
  final List<Offset>? boundary;
  final String? boundaryLabel;
  final List<TerritoryIslands> islands;

  /// Optional reference outline (present-day Vietnam) drawn as a faint dashed
  /// hairline over the era's map, so the reader sees how the borders differ from
  /// today. Purely a visual guide: never filled, never tappable, never legended.
  final List<List<Offset>>? reference;
  final String? referenceLabel;

  @override
  State<TerritoryMap> createState() => _TerritoryMapState();
}

/// A contain-fit of the projected map box inside the widget, shared by the
/// painter and the hit-tester so taps land where things are drawn.
class _Fit {
  _Fit(Size size, double aspect) {
    final availAspect = size.width / size.height;
    if (availAspect > aspect) {
      h = size.height;
      w = h * aspect;
    } else {
      w = size.width;
      h = w / aspect;
    }
    ox = (size.width - w) / 2;
    oy = (size.height - h) / 2;
  }
  late final double w, h, ox, oy;
  Offset p(Offset n) => Offset(ox + n.dx * w, oy + n.dy * h);
  Path path(List<List<Offset>> rings) {
    final path = Path();
    for (final ring in rings) {
      for (var i = 0; i < ring.length; i++) {
        final q = p(ring[i]);
        i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
      }
      path.close();
    }
    return path;
  }
}

class _TerritoryMapState extends State<TerritoryMap> {
  String? _selectedId;

  List<TerritoryRegion> get _all => <TerritoryRegion>[
        ...widget.neighbours,
        ...widget.forces,
        ...widget.islandLands,
      ];

  void _handleTap(Offset p, Size size) {
    final fit = _Fit(size, widget.mapAspect);
    // Islands sit on top of the fills, so test them first.
    for (final isl in widget.islands) {
      final c = fit.p(isl.center);
      final r = isl.radius * fit.w;
      if ((p - c).distance <= r + 10) {
        setState(() => _selectedId = 'isl:${isl.name}');
        return;
      }
    }
    for (final land in widget.islandLands) {
      if (fit.path(land.rings).contains(p)) {
        setState(() => _selectedId = land.id);
        return;
      }
    }
    // Forces first (they sit above neighbours), then neighbours.
    for (final f in widget.forces) {
      if (fit.path(f.rings).contains(p)) {
        setState(() => _selectedId = f.id);
        return;
      }
    }
    for (final n in widget.neighbours) {
      if (fit.path(n.rings).contains(p)) {
        setState(() => _selectedId = n.id);
        return;
      }
    }
    setState(() => _selectedId = null);
  }

  _CardData? _card() {
    final sel = _selectedId;
    if (sel == null) return null;
    if (sel.startsWith('isl:')) {
      final name = sel.substring(4);
      final isl = widget.islands.firstWhere((i) => i.name == name);
      return _CardData(
          title: isl.name, subtitle: isl.subtitle, color: isl.color);
    }
    final r = _all.firstWhere((r) => r.id == sel);
    return _CardData(title: r.name, subtitle: r.subtitle, color: r.color);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
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
                  neighbours: widget.neighbours,
                  islandLands: widget.islandLands,
                  mapAspect: widget.mapAspect,
                  boundary: widget.boundary,
                  boundaryLabel: widget.boundaryLabel,
                  islands: widget.islands,
                  reference: widget.reference,
                  referenceLabel: widget.referenceLabel,
                  selectedId: _selectedId,
                ),
              ),
              _Legend(forces: widget.forces, selectedId: _selectedId),
              Align(
                alignment: Alignment.bottomCenter,
                child: _InfoCard(data: _card()),
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
    required this.neighbours,
    required this.islandLands,
    required this.mapAspect,
    required this.boundary,
    required this.boundaryLabel,
    required this.islands,
    required this.reference,
    required this.referenceLabel,
    required this.selectedId,
  });

  final List<TerritoryRegion> forces;
  final List<TerritoryRegion> neighbours;
  final List<TerritoryRegion> islandLands;
  final double mapAspect;
  final List<Offset>? boundary;
  final String? boundaryLabel;
  final List<TerritoryIslands> islands;
  final List<List<Offset>>? reference;
  final String? referenceLabel;
  final String? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = _Fit(size, mapAspect);

    // Sea backdrop across the whole widget (the map letterboxes into it).
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0C1714), Color(0xFF090F0D)],
        ).createShader(Offset.zero & size),
    );

    // Neighbours: dim context, faint fill + border + label.
    for (final n in neighbours) {
      final path = fit.path(n.rings);
      final sel = n.id == selectedId;
      canvas.drawPath(
          path, Paint()..color = n.color.withValues(alpha: sel ? 0.55 : 0.30));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = VSColors.goldBorder.withValues(alpha: sel ? 0.9 : 0.4),
      );
      final at = n.labelAt;
      if (at != null) {
        _text(canvas, n.name, fit.p(at),
            color: VSColors.inkMuted, size: 9, anchor: _Anchor.center);
      }
    }

    // Forces: bright, in focus.
    for (final f in forces) {
      final path = fit.path(f.rings);
      final sel = f.id == selectedId;
      canvas.drawPath(
          path, Paint()..color = f.color.withValues(alpha: sel ? 0.95 : 0.72));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sel ? 2.2 : 1.1
          ..color = sel ? VSColors.goldBright : VSColors.goldBorder,
      );
      if (sel) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = VSColors.goldGlow.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }

    // Small island lands (Phú Quốc, Côn Đảo): bright, with a tiny label.
    for (final land in islandLands) {
      final path = fit.path(land.rings);
      final sel = land.id == selectedId;
      canvas.drawPath(
          path, Paint()..color = land.color.withValues(alpha: sel ? 0.95 : 0.8));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sel ? 1.6 : 1.0
          ..color = sel ? VSColors.goldBright : VSColors.gold,
      );
      final at = land.labelAt;
      if (at != null) {
        _text(canvas, land.name, fit.p(at).translate(6, -4),
            color: VSColors.gold, size: 8);
      }
    }

    // Reference outline: present-day Vietnam as a faint dashed hairline, so the
    // era's borders can be read against today's. A guide only — no fill.
    final ref = reference;
    if (ref != null && ref.isNotEmpty) {
      final refPath = fit.path(ref);
      _dashedPath(
        canvas,
        refPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round
          ..color = VSColors.goldBright.withValues(alpha: 0.5),
        dash: 3,
        gap: 3.5,
      );
      if (referenceLabel != null) {
        _text(canvas, referenceLabel!, Offset(fit.ox + 6, fit.oy + fit.h - 16),
            color: VSColors.gold.withValues(alpha: 0.75), size: 8.5);
      }
    }

    // Dividing line (the Gianh).
    final b = boundary;
    if (b != null && b.length == 2) {
      final p1 = fit.p(b[0]);
      final p2 = fit.p(b[1]);
      _dashed(canvas, p1, p2,
          Paint()
            ..color = VSColors.goldBright
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round);
      if (boundaryLabel != null) {
        _text(canvas, boundaryLabel!,
            Offset((p1.dx + p2.dx) / 2, math.min(p1.dy, p2.dy) - 15),
            color: VSColors.gold, size: 9.5, anchor: _Anchor.center);
      }
    }

    // Island groups.
    for (final isl in islands) {
      final c = fit.p(isl.center);
      final r = isl.radius * fit.w;
      final tint = isl.color;
      final sel = selectedId == 'isl:${isl.name}';
      _dottedCircle(canvas, c, r,
          VSColors.gold.withValues(alpha: sel ? 0.95 : 0.55));
      for (final dp in const <Offset>[
        Offset(-0.4, -0.35),
        Offset(0.15, -0.5),
        Offset(0.45, -0.1),
        Offset(-0.15, 0.05),
        Offset(0.3, 0.35),
        Offset(-0.35, 0.4),
      ]) {
        canvas.drawCircle(c + dp * r, sel ? 2.6 : 2.0,
            Paint()..color = tint.withValues(alpha: 0.95));
      }
      _text(canvas, isl.name, c.translate(0, r + 9),
          color: VSColors.gold, size: 8.5, anchor: _Anchor.center);
    }
  }

  @override
  bool shouldRepaint(_TerritoryPainter old) =>
      old.selectedId != selectedId ||
      old.forces != forces ||
      old.neighbours != neighbours ||
      old.islandLands != islandLands ||
      old.reference != reference;
}

// ─────────────────────────── overlays ───────────────────────────

class _Legend extends StatelessWidget {
  const _Legend({required this.forces, required this.selectedId});
  final List<TerritoryRegion> forces;
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
                      color: f.color
                          .withValues(alpha: f.id == selectedId ? 1 : 0.75),
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
  const _CardData({required this.title, this.subtitle, required this.color});
  final String title;
  final String? subtitle;
  final Color color;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.data});
  final _CardData? data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SizeTransition(sizeFactor: anim, child: child),
      ),
      child: d == null
          ? const SizedBox.shrink(key: ValueKey<String>('none'))
          : Container(
              key: ValueKey<String>('${d.title}${d.subtitle ?? ''}'),
              margin: const EdgeInsets.all(VSSpacing.md),
              padding: const EdgeInsets.symmetric(
                  horizontal: VSSpacing.lg, vertical: VSSpacing.md),
              decoration: BoxDecoration(
                color: VSColors.lacquerRaised.withValues(alpha: 0.95),
                borderRadius: VSRadii.cardAll,
                border: Border.all(color: VSColors.goldBorder),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: d.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: VSSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(d.title,
                            style: VSType.cardTitle.copyWith(fontSize: 15)),
                        if (d.subtitle != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(d.subtitle!,
                              style: VSType.caption.copyWith(
                                  color: VSColors.gold, fontSize: 11.5)),
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

void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
  const dash = 6.0, gap = 4.0;
  final total = (b - a).distance;
  if (total == 0) return;
  final dir = (b - a) / total;
  var t = 0.0;
  while (t < total) {
    canvas.drawLine(
        a + dir * t, a + dir * (t + dash).clamp(0, total), paint);
    t += dash + gap;
  }
}

/// Dashes along an arbitrary [path] (used for the present-day reference outline).
void _dashedPath(Canvas canvas, Path path, Paint paint,
    {double dash = 4, double gap = 4}) {
  for (final metric in path.computeMetrics()) {
    var t = 0.0;
    while (t < metric.length) {
      final end = math.min(t + dash, metric.length);
      canvas.drawPath(metric.extractPath(t, end), paint);
      t += dash + gap;
    }
  }
}

void _dottedCircle(Canvas canvas, Offset c, double r, Color color) {
  final paint = Paint()..color = color;
  const count = 26;
  for (var i = 0; i < count; i++) {
    final a = (i / count) * 2 * math.pi;
    canvas.drawCircle(c + Offset(r * math.cos(a), r * math.sin(a)), 0.8, paint);
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
            letterSpacing: 0.4,
            fontWeight: FontWeight.w600)),
    textDirection: ui.TextDirection.ltr,
  )..layout();
  final dx = anchor == _Anchor.center ? at.dx - tp.width / 2 : at.dx;
  tp.paint(canvas, Offset(dx, at.dy));
}
