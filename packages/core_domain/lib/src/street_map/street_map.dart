import '../json_util.dart' show ContentFormatException;
import '../localized_text.dart';

enum StreetTargetType { person, event, era }

enum StreetStatus { suggested, approved }

/// One thing a street is named after, plus the era whose route it opens under
/// (`/era/:era/figure/:id`, `/era/:era/event/:id`, `/era/:id`).
class StreetTarget {
  const StreetTarget({required this.type, required this.id, required this.era});

  final StreetTargetType type;
  final String id;
  final String era;

  factory StreetTarget.fromJson(Map<String, dynamic> json) {
    final type = StreetTargetType.values.asNameMap()[json['type']];
    if (type == null) {
      throw ContentFormatException('street target: bad type ${json['type']}');
    }
    return StreetTarget(
      type: type,
      id: json['id'] as String,
      era: (json['era'] ?? (type == StreetTargetType.era ? json['id'] : ''))
          as String,
    );
  }

  Map<String, dynamic> toJson() =>
      {'type': type.name, 'id': id, 'era': era};

  @override
  bool operator ==(Object other) =>
      other is StreetTarget &&
      other.type == type &&
      other.id == id &&
      other.era == era;

  @override
  int get hashCode => Object.hash(type, id, era);
}

class MappedStreet {
  const MappedStreet({
    required this.id,
    required this.name,
    required this.targets,
    required this.status,
    this.reason = '',
  });

  /// Stable slug of the normalized name, e.g. `le-loi`.
  final String id;
  final String name;
  final List<StreetTarget> targets;
  final StreetStatus status;

  /// Why the tool proposed it (`exact`, `alias`, `multi`, …); informational.
  final String reason;

  bool get isApproved => status == StreetStatus.approved;

  factory MappedStreet.fromJson(Map<String, dynamic> json) => MappedStreet(
        id: json['id'] as String,
        name: json['name'] as String,
        targets: [
          for (final t in json['targets'] as List)
            StreetTarget.fromJson(t as Map<String, dynamic>),
        ],
        status: StreetStatus.values.asNameMap()[json['status']] ??
            StreetStatus.suggested,
        reason: (json['reason'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targets': [for (final t in targets) t.toJson()],
        'status': status.name,
        if (reason.isNotEmpty) 'reason': reason,
      };

  MappedStreet copyWith({StreetStatus? status}) => MappedStreet(
        id: id,
        name: name,
        targets: targets,
        status: status ?? this.status,
        reason: reason,
      );
}

/// What kind of place a [StreetLandmark] is — picks its badge icon.
enum LandmarkKind { market, palace, church, lake, tower, airport }

/// A place to find your way by (Cycle P): drawn on the street map as a small
/// badge with its name. Not content — it has no page and no sources.
class StreetLandmark {
  const StreetLandmark({
    required this.id,
    required this.name,
    required this.kind,
    required this.lat,
    required this.lng,
    this.osm = '',
  });

  final String id;
  final LocalizedText name;
  final LandmarkKind kind;
  final double lat;
  final double lng;

  /// The OpenStreetMap object the point was taken from (`way/39514795`), so a
  /// later check can find it again. Informational; may be empty.
  final String osm;

  factory StreetLandmark.fromJson(Map<String, dynamic> json) {
    final kind = LandmarkKind.values.asNameMap()[json['kind']];
    if (kind == null) {
      throw ContentFormatException('landmark ${json['id']}: bad kind ${json['kind']}');
    }
    return StreetLandmark(
      id: json['id'] as String,
      name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>, 'landmark ${json['id']}.name'),
      kind: kind,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      osm: (json['osm'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': {'vi': name.vi, if (name.en != null) 'en': name.en},
        'kind': kind.name,
        'lat': lat,
        'lng': lng,
        if (osm.isNotEmpty) 'osm': osm,
      };
}

/// Where the street map opens: a centre and a zoom (Cycle P).
class StreetStart {
  const StreetStart({required this.lat, required this.lng, required this.zoom});

  final double lat;
  final double lng;
  final double zoom;

  factory StreetStart.fromJson(Map<String, dynamic> json) => StreetStart(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        zoom: (json['zoom'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'zoom': zoom};
}

/// `content/streets/<city>.json`.
class StreetMapFile {
  const StreetMapFile({
    required this.city,
    required this.osmSnapshot,
    required this.streets,
    this.geometry = '',
    this.basemap = '',
    this.landmarks = const [],
    this.start,
  });

  final String city;

  /// Places drawn on the map to find your way by. Empty is fine.
  final List<StreetLandmark> landmarks;

  /// Where the map opens; null = fit the whole camera lock.
  final StreetStart? start;

  /// Media path of the generated GeoJSON (`streets/hcm-streets.geojson`).
  final String geometry;

  /// Media path of the base map's PMTiles extract
  /// (`streets/hcm-basemap.pmtiles`) — the roads, rivers and place names drawn
  /// under the gold streets. Empty = no base map (the plain ground).
  final String basemap;
  final String osmSnapshot;
  final List<MappedStreet> streets;

  factory StreetMapFile.fromJson(Map<String, dynamic> json) => StreetMapFile(
        city: json['city'] as String,
        osmSnapshot: (json['osmSnapshot'] as String?) ?? '',
        geometry: (json['geometry'] as String?) ?? '',
        basemap: (json['basemap'] as String?) ?? '',
        landmarks: [
          for (final l in (json['landmarks'] as List?) ?? const [])
            StreetLandmark.fromJson(l as Map<String, dynamic>),
        ],
        start: json['start'] == null ? null : StreetStart.fromJson(json['start'] as Map<String, dynamic>),
        streets: [
          for (final s in json['streets'] as List)
            MappedStreet.fromJson(s as Map<String, dynamic>),
        ],
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'city': city,
        'osmSnapshot': osmSnapshot,
        if (geometry.isNotEmpty) 'geometry': geometry,
        if (basemap.isNotEmpty) 'basemap': basemap,
        if (start != null) 'start': start!.toJson(),
        if (landmarks.isNotEmpty) 'landmarks': [for (final l in landmarks) l.toJson()],
        'streets': [for (final s in streets) s.toJson()],
      };

  List<MappedStreet> get approved =>
      [for (final s in streets) if (s.isApproved) s];

  /// Approved streets that point at the given target — drives the reverse
  /// chip on Character/Event detail pages.
  List<MappedStreet> streetsFor(StreetTargetType type, String id) => [
        for (final s in approved)
          if (s.targets.any((t) => t.type == type && t.id == id)) s,
      ];
}
