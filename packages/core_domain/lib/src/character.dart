import 'package:meta/meta.dart';

import 'asset_ref.dart';
import 'json_util.dart';
import 'localized_text.dart';

/// A legendary or historical figure of an era, with portrait art. Events
/// reference characters by [id]; the era holds the roster (single source, no
/// duplication).
///
/// Two art conventions coexist. Legacy figures carry a single [portrait]
/// three-panel reference sheet that the app crops (bust top-right, full-body
/// left). Newer figures instead carry dedicated [avatar] (square headshot) and
/// [fullBody] (standing figure) images, rendered whole with no cropping — which
/// avoids the stray sheet borders that made cropped panels look off-centre.
@immutable
class Character {
  const Character({
    required this.id,
    required this.name,
    this.portrait,
    this.avatar,
    this.fullBody,
    this.epithet,
    this.bio,
  });

  final String id;
  final LocalizedText name;

  /// Short honorific/role, e.g. "Bố Rồng" / "The Dragon Father".
  final LocalizedText? epithet;

  /// Chronicle-grounded life summary for the character detail page. Optional.
  final LocalizedText? bio;

  /// Legacy three-panel reference sheet, cropped by the app. Absent for figures
  /// that supply dedicated [avatar]/[fullBody] art instead.
  final AssetRef? portrait;

  /// Dedicated square headshot, rendered whole in figure tiles. Falls back to a
  /// bust crop of [portrait] when absent.
  final AssetRef? avatar;

  /// Dedicated standing-figure image, rendered whole on the detail page. Falls
  /// back to a full-body crop of [portrait] when absent.
  final AssetRef? fullBody;

  factory Character.fromJson(Map<String, dynamic> json, [String at = 'character']) {
    final epithet = json.objOrNull('epithet', at: at);
    final bio = json.objOrNull('bio', at: at);
    final portrait = json.objOrNull('portrait', at: at);
    final avatar = json.objOrNull('avatar', at: at);
    final fullBody = json.objOrNull('fullBody', at: at);
    return Character(
      id: json.str('id', at: at),
      name: LocalizedText.fromJson(json.obj('name', at: at), '$at.name'),
      epithet:
          epithet == null ? null : LocalizedText.fromJson(epithet, '$at.epithet'),
      bio: bio == null ? null : LocalizedText.fromJson(bio, '$at.bio'),
      portrait:
          portrait == null ? null : AssetRef.fromJson(portrait, '$at.portrait'),
      avatar: avatar == null ? null : AssetRef.fromJson(avatar, '$at.avatar'),
      fullBody:
          fullBody == null ? null : AssetRef.fromJson(fullBody, '$at.fullBody'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Character &&
      other.id == id &&
      other.name == name &&
      other.epithet == epithet &&
      other.bio == bio &&
      other.portrait == portrait &&
      other.avatar == avatar &&
      other.fullBody == fullBody;

  @override
  int get hashCode =>
      Object.hash(id, name, epithet, bio, portrait, avatar, fullBody);
}

/// A per-era reference to a person in the registry, with optional overrides.
///
/// A recurring figure (e.g. Triệu Đà, later Triệu Vũ Đế) is one [id] in the
/// registry; an era points at it with [ref] and may override the name, epithet,
/// bio or portrait for its own context — never a second person.
@immutable
class CharacterRef {
  const CharacterRef({
    required this.ref,
    this.name,
    this.epithet,
    this.bio,
    this.portrait,
    this.avatar,
    this.fullBody,
  });

  /// Id of a person in the registry (also what event `figureIds` use).
  final String ref;
  final LocalizedText? name;
  final LocalizedText? epithet;
  final LocalizedText? bio;
  final AssetRef? portrait;
  final AssetRef? avatar;
  final AssetRef? fullBody;

  factory CharacterRef.fromJson(Map<String, dynamic> json,
      [String at = 'characterRef']) {
    final name = json.objOrNull('name', at: at);
    final epithet = json.objOrNull('epithet', at: at);
    final bio = json.objOrNull('bio', at: at);
    final portrait = json.objOrNull('portrait', at: at);
    final avatar = json.objOrNull('avatar', at: at);
    final fullBody = json.objOrNull('fullBody', at: at);
    return CharacterRef(
      ref: json.str('ref', at: at),
      name: name == null ? null : LocalizedText.fromJson(name, '$at.name'),
      epithet:
          epithet == null ? null : LocalizedText.fromJson(epithet, '$at.epithet'),
      bio: bio == null ? null : LocalizedText.fromJson(bio, '$at.bio'),
      portrait:
          portrait == null ? null : AssetRef.fromJson(portrait, '$at.portrait'),
      avatar: avatar == null ? null : AssetRef.fromJson(avatar, '$at.avatar'),
      fullBody:
          fullBody == null ? null : AssetRef.fromJson(fullBody, '$at.fullBody'),
    );
  }

  /// Resolve against the canonical [base] person: any override wins, else the
  /// canonical value. The resolved character's id is [ref].
  Character resolve(Character base) => Character(
        id: ref,
        name: name ?? base.name,
        epithet: epithet ?? base.epithet,
        bio: bio ?? base.bio,
        portrait: portrait ?? base.portrait,
        avatar: avatar ?? base.avatar,
        fullBody: fullBody ?? base.fullBody,
      );
}
