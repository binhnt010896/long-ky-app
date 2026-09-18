import 'package:meta/meta.dart';

import 'character.dart';
import 'json_util.dart';

/// The single source of identity for every figure, keyed by id.
///
/// Loaded from `content/people.json`. Eras resolve their [CharacterRef]s against
/// this registry, so a person is defined once and referenced everywhere.
@immutable
class PeopleRegistry {
  const PeopleRegistry(this.byId);

  final Map<String, Character> byId;

  /// An empty registry — used where no people are needed (e.g. malformed-input
  /// tests that fail before characters are resolved).
  static const PeopleRegistry empty = PeopleRegistry(<String, Character>{});

  factory PeopleRegistry.fromJson(Map<String, dynamic> json) {
    final people =
        json.list<Character>('people', Character.fromJson, at: 'people');
    return PeopleRegistry(<String, Character>{
      for (final p in people) p.id: p,
    });
  }

  Character? operator [](String id) => byId[id];
}
