import 'dart:ui';

/// How a region reads on the map.
/// - [core]: the era's own state(s), bright and legend-listed.
/// - [rival]: a competing Vietnamese state in a split era (Mạc vs Lê–Trịnh,
///   Trịnh vs Nguyễn, Tây Sơn vs Nguyễn Ánh) — bright, its own colour.
/// - [protectorate]: land held as a protectorate / claim (e.g. Minh Mạng over
///   Cambodia & Laos, French Annam–Tonkin) — faded + hatched, not full territory.
/// - [neighbour]: dim context polity.
enum AtlasRole { core, rival, protectorate, neighbour }

/// One polity in an [AtlasSnapshot]. [color] is a packed 0xAARRGGBB int;
/// [rings] are normalized polygon rings (x,y in 0..1, y down).
class AtlasRegion {
  const AtlasRegion({
    required this.id,
    required this.name,
    required this.color,
    required this.role,
    required this.rings,
    this.subtitle,
    this.labelAt,
  });

  final String id;
  final String name;
  final String? subtitle;
  final int color;
  final AtlasRole role;
  final Offset? labelAt;
  final List<List<Offset>> rings;
}

/// A dynasty-keyed snapshot of the territory. [eras] are the era slugs this
/// snapshot covers (the map is opened for an era and shows its snapshot);
/// [anchorYear] places it on the timeline scrubber. [title]/[subtitle] name the
/// polity/period for the header.
class AtlasSnapshot {
  const AtlasSnapshot({
    required this.id,
    required this.title,
    required this.anchorYear,
    required this.eras,
    required this.mapAspect,
    required this.regions,
    this.subtitle,
    this.boundary,
    this.boundaryLabel,
  });

  final String id;
  final String title;
  final String? subtitle;
  final int anchorYear;
  final List<String> eras;
  final double mapAspect;
  final List<AtlasRegion> regions;
  final List<Offset>? boundary;
  final String? boundaryLabel;
}
