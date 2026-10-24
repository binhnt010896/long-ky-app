import '../character.dart';
import '../era.dart';
import '../today_pick.dart';
import 'stable_hash.dart';

/// Eras that start before this year are in the unlock game; from it on the art
/// is photographs, and no silhouette may imply a photographed face.
const int kHiddenArtBeforeYear = 1884;

/// Whether [era]'s portraits and event pictures take part in the unlock game.
bool hasHiddenArt(Era era) {
  final start = era.yearRange.startYear;
  return start != null && start < kHiddenArtBeforeYear;
}

/// Rulers whose epithet does not say so ("Cháu nối nghiệp", "Lê Ngọa Triều"…).
const Set<String> kRulerIds = <String>{
  'kinh-duong-vuong',
  'lac-long-quan',
  'trieu-van-de',
  'le-hoan',
  'le-long-dinh',
};

final RegExp _rulerEpithet = RegExp(
    r'Vua|Chúa|Hoàng đế|Nữ hoàng|Vương|Thủ lĩnh|Lãnh tụ|Thái Tổ|Thánh Tông|Bố Cái');

/// Whether [c] is a king or leader: an era's first roster person ([isLead]), a
/// ruler by epithet (Vua, Chúa, Hoàng đế, …Vương, Thủ lĩnh), or one of
/// [kRulerIds]. Their portraits are always hidden.
bool isRuler(Character c, {bool isLead = false}) =>
    isLead ||
    kRulerIds.contains(c.id) ||
    _rulerEpithet.hasMatch(c.epithet?.vi ?? '');

/// The [VisitKey]s (person and event) whose art starts hidden.
///
/// Fixed by the content, the same for every reader. Every king or leader
/// ([isRuler]) is hidden; on top of that, in each in-scope era the roster is
/// hidden up to half (rounded down), and half of the events, chosen by a
/// stable hash of the id. An era's first event is never hidden, so its hub
/// always opens on a picture. A person on two rosters is decided once, by id.
Set<String> hiddenArtKeys(Iterable<Era> eras) {
  final inScope = [for (final e in eras) if (hasHiddenArt(e)) e];

  // The first event of each era is protected up front.
  final protected = <String>{
    for (final era in inScope)
      if (era.events.isNotEmpty) VisitKey.event(era.events.first.id),
  };

  // Every king and leader is hidden, wherever they sit.
  final hidden = <String>{
    for (final era in inScope)
      for (var i = 0; i < era.characters.length; i++)
        if (isRuler(era.characters[i], isLead: i == 0))
          VisitKey.person(era.characters[i].id),
  };
  final decided = <String>{...hidden};

  void decide(List<String> keys) {
    final target = keys.length ~/ 2;
    final already = keys.where(hidden.contains).length;
    final pool = [
      for (final k in keys)
        if (!decided.contains(k) && !protected.contains(k)) k,
    ]..sort((a, b) {
        final c = stableHash(a).compareTo(stableHash(b));
        return c != 0 ? c : a.compareTo(b);
      });
    final need = target - already;
    for (var i = 0; i < need && i < pool.length; i++) {
      hidden.add(pool[i]);
    }
    decided.addAll(keys);
  }

  for (final era in inScope) {
    decide([for (final c in era.characters) VisitKey.person(c.id)]);
    decide([for (final e in era.events) VisitKey.event(e.id)]);
  }
  return hidden;
}
