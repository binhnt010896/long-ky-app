import 'dart:ui';

/// One polity in an [AtlasYear]. [bright] marks the era's focal Vietnamese
/// polities (Đại Việt, Champa, the divided lords…); others are dim context.
/// [color] is a packed 0xAARRGGBB int; [rings] are normalized polygon rings.
class AtlasRegion {
  const AtlasRegion({
    required this.id,
    required this.name,
    required this.color,
    required this.bright,
    required this.rings,
    this.subtitle,
    this.labelAt,
  });

  final String id;
  final String name;
  final String? subtitle;
  final int color;
  final bool bright;
  final Offset? labelAt;
  final List<List<Offset>> rings;
}

/// A single dated snapshot of the map.
class AtlasYear {
  const AtlasYear({
    required this.year,
    required this.mapAspect,
    required this.regions,
    this.boundary,
    this.boundaryLabel,
  });

  final int year;
  final double mapAspect;
  final List<AtlasRegion> regions;
  final List<Offset>? boundary;
  final String? boundaryLabel;
}
