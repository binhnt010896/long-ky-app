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

/// The [VisitKey]s (person and event) whose art starts hidden.
///
/// Fixed by the content, the same for every reader: in each in-scope era, half
/// of the roster and half of the events (rounded down), chosen by a stable
/// hash of the id. An era's first roster person and first event are never
/// hidden, so its hub always opens on a face and a picture. A person on two
/// rosters is decided once, by id.
Set<String> hiddenArtKeys(Iterable<Era> eras) {
  final inScope = [for (final e in eras) if (hasHiddenArt(e)) e];

  // The era leads are protected up front, so a later era can't hide an
  // earlier era's lead person.
  final protected = <String>{
    for (final era in inScope) ...[
      if (era.characters.isNotEmpty) VisitKey.person(era.characters.first.id),
      if (era.events.isNotEmpty) VisitKey.event(era.events.first.id),
    ],
  };

  final hidden = <String>{};
  final decided = <String>{};

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
