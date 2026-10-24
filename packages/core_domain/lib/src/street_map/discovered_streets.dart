import '../today_pick.dart';
import 'street_map.dart';

/// The [VisitKey] a street [target] is discovered by.
String visitKeyForTarget(StreetTarget target) => switch (target.type) {
      StreetTargetType.person => VisitKey.person(target.id),
      StreetTargetType.event => VisitKey.event(target.id),
      StreetTargetType.era => VisitKey.era(target.id),
    };

/// The ids of the approved [streets] the reader has discovered: those with at
/// least one target in [visited] (a set of [VisitKey]s). Pure; the map paints
/// these in a second tone.
Set<String> discoveredStreetIds(
  Iterable<MappedStreet> streets,
  Set<String> visited,
) {
  if (visited.isEmpty) return const <String>{};
  return <String>{
    for (final s in streets)
      if (s.isApproved && s.targets.any((t) => visited.contains(visitKeyForTarget(t))))
        s.id,
  };
}

/// The person and event [VisitKey]s some approved street points at, for
/// [todayPick]'s preference for picks that light a street. (Era targets are
/// left out: "Hôm nay" never picks an era.)
Set<String> streetPickKeys(Iterable<MappedStreet> streets) => <String>{
      for (final s in streets)
        if (s.isApproved)
          for (final t in s.targets)
            if (t.type != StreetTargetType.era) visitKeyForTarget(t),
    };
