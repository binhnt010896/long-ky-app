import 'package:meta/meta.dart';

import 'json_util.dart';
import 'localized_text.dart';

/// What kind of asset a slot holds. The immersive layer degrades by tier, so a
/// slot can be a Rive animation at flagship and a static image at reduced.
enum AssetType { image, rive, particles, gradient }

/// Semantic role of an asset within a scene or screen.
enum AssetRole { cover, hero, sky, mid, foreground, overlay, particles }

/// A tier-aware reference to a visual asset.
///
/// [flagship] may be an animated/Rive source; [reduced] is the static fallback;
/// [placeholder] names a built-in stand-in (e.g. `era-scene` gradient) used
/// until real sơn mài art lands. The widget layer picks among these by the
/// active ExperienceTier — never assume a capability, query the tier.
@immutable
class AssetRef {
  const AssetRef({
    required this.id,
    required this.type,
    this.role,
    this.depth,
    this.flagship,
    this.reduced,
    this.placeholder,
    this.caption,
    this.credit,
  });

  final String id;
  final AssetType type;
  final AssetRole? role;

  /// Parallax depth, 0 (far) → 1 (near). Null when not a scene layer.
  final double? depth;

  /// Flagship-tier source (may be Rive/animated).
  final String? flagship;

  /// Static fallback source for reduced/trailer tiers.
  final String? reduced;

  /// Name of a built-in placeholder to render until real art exists.
  final String? placeholder;

  final LocalizedText? caption;
  final String? credit;

  /// True while this slot has no real art and should render its placeholder.
  bool get isPlaceholder => flagship == null && reduced == null;

  factory AssetRef.fromJson(Map<String, dynamic> json, [String at = 'asset']) {
    final caption = json.objOrNull('caption', at: at);
    final depthRaw = json['depth'];
    return AssetRef(
      id: json.str('id', at: at),
      type: _assetType(json.str('type', at: at), at),
      role: _assetRole(json.strOrNull('role', at: at), at),
      depth: depthRaw == null ? null : (depthRaw as num).toDouble(),
      flagship: json.strOrNull('flagship', at: at),
      reduced: json.strOrNull('reduced', at: at),
      placeholder: json.strOrNull('placeholder', at: at),
      caption: caption == null
          ? null
          : LocalizedText.fromJson(caption, '$at.caption'),
      credit: json.strOrNull('credit', at: at),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AssetRef &&
      other.id == id &&
      other.type == type &&
      other.role == role &&
      other.depth == depth &&
      other.flagship == flagship &&
      other.reduced == reduced &&
      other.placeholder == placeholder &&
      other.caption == caption &&
      other.credit == credit;

  @override
  int get hashCode => Object.hash(
        id,
        type,
        role,
        depth,
        flagship,
        reduced,
        placeholder,
        caption,
        credit,
      );
}

AssetType _assetType(String raw, String at) => switch (raw) {
      'image' => AssetType.image,
      'rive' => AssetType.rive,
      'particles' => AssetType.particles,
      'gradient' => AssetType.gradient,
      _ => throw ContentFormatException('unknown asset type `$raw`', path: at),
    };

AssetRole? _assetRole(String? raw, String at) => switch (raw) {
      null => null,
      'cover' => AssetRole.cover,
      'hero' => AssetRole.hero,
      'sky' => AssetRole.sky,
      'mid' => AssetRole.mid,
      'foreground' => AssetRole.foreground,
      'overlay' => AssetRole.overlay,
      'particles' => AssetRole.particles,
      _ => throw ContentFormatException('unknown asset role `$raw`', path: at),
    };
