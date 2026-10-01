import 'dart:math' as math;

/// A planar or geographic point. For lat/lng use x = lng, y = lat.
class GeoPt {
  const GeoPt(this.x, this.y);
  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is GeoPt && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

const _mPerDegLat = 111320.0;

/// Douglas–Peucker over lng/lat, with [toleranceM] in metres (equirectangular
/// projection around the line's mean latitude — plenty at city scale).
List<GeoPt> simplifyLine(List<GeoPt> pts, double toleranceM) {
  if (pts.length < 3) return List.of(pts);
  final lat0 = pts.fold<double>(0, (s, p) => s + p.y) / pts.length;
  final kx = _mPerDegLat * math.cos(lat0 * math.pi / 180);
  final keep = List<bool>.filled(pts.length, false)
    ..[0] = true
    ..[pts.length - 1] = true;
  final stack = <(int, int)>[(0, pts.length - 1)];
  while (stack.isNotEmpty) {
    final (a, b) = stack.removeLast();
    var maxD = -1.0;
    var idx = -1;
    for (var i = a + 1; i < b; i++) {
      final d = _segDist(pts[i].x * kx, pts[i].y * _mPerDegLat, pts[a].x * kx,
          pts[a].y * _mPerDegLat, pts[b].x * kx, pts[b].y * _mPerDegLat);
      if (d > maxD) {
        maxD = d;
        idx = i;
      }
    }
    if (maxD > toleranceM && idx != -1) {
      keep[idx] = true;
      stack..add((a, idx))..add((idx, b));
    }
  }
  return [for (var i = 0; i < pts.length; i++) if (keep[i]) pts[i]];
}

double _segDist(double px, double py, double ax, double ay, double bx, double by) {
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0) return math.sqrt(math.pow(px - ax, 2) + math.pow(py - ay, 2));
  final t = (((px - ax) * dx + (py - ay) * dy) / len2).clamp(0.0, 1.0);
  final cx = ax + t * dx, cy = ay + t * dy;
  return math.sqrt(math.pow(px - cx, 2) + math.pow(py - cy, 2));
}

/// Rounds a coordinate to [places] decimals (5 ≈ 1 m).
double roundCoord(double v, [int places = 5]) {
  final f = math.pow(10, places).toDouble();
  return (v * f).roundToDouble() / f;
}

/// Joins segments that share an end point into longer polylines (OSM splits a
/// street into many ways). Greedy end-to-end chaining; a segment is reversed
/// when that is what makes it join. Order of the result is deterministic.
List<List<GeoPt>> chainSegments(List<List<GeoPt>> segments) {
  final pool = [
    for (final s in segments) if (s.length >= 2) List.of(s),
  ];
  final out = <List<GeoPt>>[];
  while (pool.isNotEmpty) {
    var cur = pool.removeAt(0);
    var joined = true;
    while (joined) {
      joined = false;
      for (var i = 0; i < pool.length; i++) {
        final s = pool[i];
        if (cur.last == s.first) {
          cur = [...cur, ...s.skip(1)];
        } else if (cur.last == s.last) {
          cur = [...cur, ...s.reversed.skip(1)];
        } else if (cur.first == s.last) {
          cur = [...s, ...cur.skip(1)];
        } else if (cur.first == s.first) {
          cur = [...s.reversed, ...cur.skip(1)];
        } else {
          continue;
        }
        pool.removeAt(i);
        joined = true;
        break;
      }
    }
    out.add(cur);
  }
  return out;
}

/// Full per-street pipeline: chain, simplify to ~[toleranceM], round.
List<List<GeoPt>> buildStreetLines(List<List<GeoPt>> segments,
    {double toleranceM = 5, int places = 5}) {
  return [
    for (final line in chainSegments(segments))
      [
        for (final p in simplifyLine(line, toleranceM))
          GeoPt(roundCoord(p.x, places), roundCoord(p.y, places)),
      ],
  ];
}

/// Distance in [unit]s from [p] to the polyline [line] (both in the same
/// planar space, e.g. screen dp).
double distanceToPolyline(GeoPt p, List<GeoPt> line) {
  var best = double.infinity;
  for (var i = 0; i + 1 < line.length; i++) {
    final d = _segDist(p.x, p.y, line[i].x, line[i].y, line[i + 1].x, line[i + 1].y);
    if (d < best) best = d;
  }
  return best;
}

/// Hit-testing for the street map: the id of the nearest street whose
/// polyline passes within [toleranceDp] of [tap], or null. All geometry must
/// already be projected to screen space; ties go to the nearer street, then
/// to the lexicographically smaller id so results are stable.
String? hitTestStreet(
  GeoPt tap,
  Map<String, List<List<GeoPt>>> screenLinesById, {
  double toleranceDp = 24,
}) {
  String? bestId;
  var bestD = toleranceDp;
  for (final e in screenLinesById.entries) {
    for (final line in e.value) {
      final d = distanceToPolyline(tap, line);
      if (d < bestD || (d == bestD && bestId != null && e.key.compareTo(bestId) < 0)) {
        bestD = d;
        bestId = e.key;
      }
    }
  }
  return bestId;
}

/// Even-odd point-in-polygon over [rings] (outer rings and holes alike, as a
/// GeoJSON MultiPolygon flattened). Points are x = lng, y = lat.
bool pointInRings(GeoPt p, List<List<GeoPt>> rings) {
  var inside = false;
  for (final ring in rings) {
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i], b = ring[j];
      if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
        inside = !inside;
      }
    }
  }
  return inside;
}
