import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ui_kit/ui_kit.dart';

/// Below this zoom the landmarks hide: at that scale they would only be a blob
/// in the middle of the city.
const double kLandmarkMinZoom = 11;

/// Diameter of a landmark's round badge, in logical pixels — smaller while the
/// map is zoomed out (below [kLandmarkFullZoom]), where Bến Thành, Đức Bà,
/// Hồ Con Rùa and Dinh Độc Lập are only a few pixels apart.
const double kLandmarkBadge = 28;
const double kLandmarkSmallBadge = 22;
const double kLandmarkFullZoom = 14;

const double _kLabelGap = 3;
const double _kLabelHeight = 16;
const double _kLabelPad = 4;

/// A landmark put on the screen: its badge, and its name when there is room.
class LandmarkPlacement {
  const LandmarkPlacement({
    required this.landmark,
    required this.badge,
    this.label,
  });

  final StreetLandmark landmark;
  final Rect badge;

  /// Null when the name would overlap a higher-priority landmark's name or
  /// any badge — it comes back as the reader zooms in.
  final Rect? label;
}

/// Lays [landmarks] (already in priority order: earlier wins) out in screen
/// space. Pure, so it is unit-tested without a map.
///
/// Every badge on screen is always kept. A label is kept only if it does not
/// overlap an already-kept label or any other landmark's badge.
List<LandmarkPlacement> placeLandmarks({
  required List<StreetLandmark> landmarks,
  required Offset Function(StreetLandmark) project,
  required Size viewport,
  required Lang lang,
  required double Function(String text) measureWidth,
  double badgeSize = kLandmarkBadge,
}) {
  final r = badgeSize / 2;
  final screen = (Offset.zero & viewport).inflate(40);
  final visible = <(StreetLandmark, Offset)>[
    for (final l in landmarks)
      if (screen.contains(project(l))) (l, project(l)),
  ];
  final badges = [
    for (final (_, c) in visible) Rect.fromCircle(center: c, radius: r),
  ];
  final keptLabels = <Rect>[];
  final out = <LandmarkPlacement>[];
  for (var i = 0; i < visible.length; i++) {
    final (l, c) = visible[i];
    final w = measureWidth(l.name.resolve(lang)) + 2 * _kLabelPad;
    final label = Rect.fromLTWH(
      c.dx - w / 2,
      c.dy + r + _kLabelGap,
      w,
      _kLabelHeight,
    );
    // A name half off the screen edge reads as a glitch: hide it until the
    // reader pans the landmark in.
    var clear = (Offset.zero & viewport).contains(label.topLeft) &&
        (Offset.zero & viewport).contains(label.bottomRight);
    for (var j = 0; j < badges.length && clear; j++) {
      if (j != i && label.overlaps(badges[j])) clear = false;
    }
    for (final k in keptLabels) {
      if (clear && label.overlaps(k)) clear = false;
    }
    if (clear) keptLabels.add(label);
    out.add(
      LandmarkPlacement(
        landmark: l,
        badge: badges[i],
        label: clear ? label : null,
      ),
    );
  }
  return out;
}

/// The badge icon for a kind of place.
IconData landmarkIcon(LandmarkKind kind) => switch (kind) {
  LandmarkKind.market => Icons.storefront_outlined,
  LandmarkKind.palace => Icons.account_balance_outlined,
  LandmarkKind.church => Icons.church_outlined,
  LandmarkKind.lake => Icons.water_outlined,
  LandmarkKind.tower => Icons.apartment_outlined,
  LandmarkKind.airport => Icons.flight_outlined,
};

const TextStyle _labelBase = TextStyle(fontSize: 11.5, height: 1.1);

/// The landmarks of the street map: small gold-ringed badges with the place's
/// name beneath, redrawn as the camera moves. Ignores touches — the gold
/// streets stay the only tappable thing (decision M2/P4).
class StreetLandmarkLayer extends StatelessWidget {
  const StreetLandmarkLayer({
    required this.landmarks,
    required this.lang,
    super.key,
  });

  final List<StreetLandmark> landmarks;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    if (landmarks.isEmpty || camera.zoom < kLandmarkMinZoom) {
      return const SizedBox.shrink();
    }
    final style = VSType.caption.merge(_labelBase);
    double measure(String text) {
      final p = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    final small = camera.zoom < kLandmarkFullZoom;
    final badgeSize = small ? kLandmarkSmallBadge : kLandmarkBadge;
    final placed = placeLandmarks(
      badgeSize: badgeSize,
      landmarks: landmarks,
      project: (l) {
        final p = camera.latLngToScreenPoint(LatLng(l.lat, l.lng));
        return Offset(p.x, p.y);
      },
      viewport: Size(camera.size.x, camera.size.y),
      lang: lang,
      measureWidth: measure,
    );

    return IgnorePointer(
      child: Stack(
        key: const Key('street-landmarks'),
        children: <Widget>[
          // Painted last-priority first, so where badges overlap the more
          // important one is on top.
          for (final p in placed.reversed) ...<Widget>[
            Positioned.fromRect(
              rect: p.badge,
              child: Semantics(
                label: p.landmark.name.resolve(lang),
                child: DecoratedBox(
                  key: Key('landmark-${p.landmark.id}'),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: VSColors.lacquer.withValues(alpha: 0.9),
                    border: Border.all(color: VSColors.gold, width: 0.9),
                  ),
                  child: Icon(
                    landmarkIcon(p.landmark.kind),
                    size: 15,
                    color: VSColors.goldBright,
                  ),
                ),
              ),
            ),
            if (p.label != null)
              Positioned.fromRect(
                rect: p.label!,
                child: ExcludeSemantics(
                  child: _Halo(
                    key: Key('landmark-label-${p.landmark.id}'),
                    text: p.landmark.name.resolve(lang),
                    style: style,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Cream text with a soft dark outline, so it reads over roads and water.
class _Halo extends StatelessWidget {
  const _Halo({required this.text, required this.style, super.key});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final outline = style.copyWith(
      color: null,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = VSColors.lacquer.withValues(alpha: 0.9),
    );
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Text(
          text,
          style: outline,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          textAlign: TextAlign.center,
        ),
        Text(
          text,
          style: style.copyWith(color: VSColors.parchment),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
