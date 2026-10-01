import '../json_util.dart' show ContentFormatException;

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

/// `content/streets/<city>.json`.
class StreetMapFile {
  const StreetMapFile({
    required this.city,
    required this.osmSnapshot,
    required this.streets,
    this.geometry = '',
    this.basemap = '',
  });

  final String city;

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
