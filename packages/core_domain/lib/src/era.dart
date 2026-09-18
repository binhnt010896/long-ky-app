import 'package:meta/meta.dart';

import 'asset_ref.dart';
import 'character.dart';
import 'citation.dart';
import 'history_event.dart';
import 'json_util.dart';
import 'localized_text.dart';
import 'people.dart';
import 'year.dart';

/// An era's colour identity, as raw hex strings (Flutter-free).
///
/// The UI layer turns [accent] into a full sơn mài scene (see ui_kit's
/// `VSEraPalette.fromAccent`); [scene] is an optional explicit override of the
/// derived gradient stops.
@immutable
class EraPalette {
  const EraPalette({required this.accent, this.particle, this.scene});

  /// Signature accent, `#RRGGBB`.
  final String accent;

  /// Optional ambient-particle colour, `#RRGGBB`.
  final String? particle;

  /// Optional explicit scene gradient stops (top → bottom), each `#RRGGBB`.
  final List<String>? scene;

  factory EraPalette.fromJson(Map<String, dynamic> json,
      [String at = 'palette']) {
    final sceneRaw = json['scene'];
    List<String>? scene;
    if (sceneRaw is List) {
      scene = <String>[
        for (final s in sceneRaw)
          if (s is String)
            s
          else
            throw ContentFormatException('scene stop is not a string',
                path: '$at.scene'),
      ];
    } else if (sceneRaw != null) {
      throw ContentFormatException('`scene` is not a list', path: '$at.scene');
    }
    return EraPalette(
      accent: json.str('accent', at: at),
      particle: json.strOrNull('particle', at: at),
      scene: scene,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EraPalette &&
      other.accent == accent &&
      other.particle == particle &&
      _listEq(other.scene, scene);

  @override
  int get hashCode =>
      Object.hash(accent, particle, scene == null ? null : Object.hashAll(scene!));
}

/// An era — the top-level content unit, mirroring `era.schema.json`.
@immutable
class Era {
  const Era({
    required this.schemaVersion,
    required this.id,
    required this.slug,
    required this.order,
    required this.title,
    required this.kicker,
    required this.subtitle,
    required this.yearRange,
    required this.palette,
    required this.primarySource,
    required this.events,
    this.period,
    this.overview,
    this.cover,
    this.sceneLayers = const <AssetRef>[],
    this.characters = const <Character>[],
    this.flagship = false,
  });

  final int schemaVersion;
  final String id;
  final String slug;
  final int order;

  /// Id of the dynasty / period this era belongs to (see [Period]). The dynasty
  /// hub groups eras under their period. Null only in fixtures/older content.
  final String? period;
  final LocalizedText title;
  final LocalizedText kicker;
  final LocalizedText subtitle;

  /// Editorial intro paragraph shown on the Era Hub. Optional.
  final LocalizedText? overview;
  final YearRange yearRange;
  final EraPalette palette;

  /// The single chronicle this era draws from (single-source rule).
  final Citation primarySource;

  /// Events in authored order (already sorted by [HistoryEvent.order]).
  final List<HistoryEvent> events;

  final AssetRef? cover;

  /// Parallax scene slots, back → front.
  final List<AssetRef> sceneLayers;

  /// Roster of figures in this era; events reference them by id.
  final List<Character> characters;

  /// Whether this era is a "peak" — a rare high point given a distinguished
  /// treatment in the UI (a badge and warmer aura on Home, a dominant node on
  /// the global timeline). Defaults to false; only a handful of eras set it.
  final bool flagship;

  /// The characters appearing in [event], in the event's declared order.
  /// Ids with no matching roster entry are skipped.
  List<Character> charactersFor(HistoryEvent event) {
    if (event.figureIds.isEmpty || characters.isEmpty) return const <Character>[];
    final byId = <String, Character>{for (final c in characters) c.id: c};
    return <Character>[
      for (final id in event.figureIds)
        if (byId[id] case final c?) c,
    ];
  }

  /// The character with [id] from the roster, or null if absent.
  Character? figureById(String id) {
    for (final c in characters) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// The events in which the figure [figureId] appears, in authored order.
  List<HistoryEvent> eventsWithFigure(String figureId) => <HistoryEvent>[
        for (final e in events)
          if (e.figureIds.contains(figureId)) e,
      ];

  /// The events related to [event], in its declared order. Unknown ids and the
  /// event itself are skipped.
  List<HistoryEvent> relatedEventsFor(HistoryEvent event) {
    if (event.relatedEventIds.isEmpty) return const <HistoryEvent>[];
    final byId = <String, HistoryEvent>{for (final e in events) e.id: e};
    return <HistoryEvent>[
      for (final id in event.relatedEventIds)
        if (id != event.id && byId[id] != null) byId[id]!,
    ];
  }

  /// Parse an era. Character entries are references into [people] (the registry
  /// from `content/people.json`), resolved here with any per-era overrides.
  factory Era.fromJson(Map<String, dynamic> json, PeopleRegistry people) {
    const at = 'era';
    final cover = json.objOrNull('cover', at: at);
    final scene = json.objOrNull('scene', at: at);
    final layers = scene == null
        ? const <AssetRef>[]
        : scene.list<AssetRef>('layers', AssetRef.fromJson, at: '$at.scene');

    final events = json.list<HistoryEvent>('events', HistoryEvent.fromJson,
        at: at)
      ..sort((a, b) => a.order.compareTo(b.order));

    final refs = json['characters'] == null
        ? const <CharacterRef>[]
        : json.list<CharacterRef>('characters', CharacterRef.fromJson, at: at);
    final characters = <Character>[];
    for (final ref in refs) {
      final base = people[ref.ref];
      if (base == null) {
        throw ContentFormatException(
          'unknown person ref `${ref.ref}` (not in content/people.json)',
          path: '$at.characters',
        );
      }
      characters.add(ref.resolve(base));
    }

    final overview = json.objOrNull('overview', at: at);

    return Era(
      schemaVersion: json.integer('schemaVersion', at: at),
      id: json.str('id', at: at),
      slug: json.str('slug', at: at),
      order: json.integer('order', at: at),
      period: json.strOrNull('period', at: at),
      title: LocalizedText.fromJson(json.obj('title', at: at), '$at.title'),
      kicker: LocalizedText.fromJson(json.obj('kicker', at: at), '$at.kicker'),
      subtitle:
          LocalizedText.fromJson(json.obj('subtitle', at: at), '$at.subtitle'),
      overview: overview == null
          ? null
          : LocalizedText.fromJson(overview, '$at.overview'),
      yearRange: YearRange.fromJson(json.obj('yearRange', at: at), '$at.yearRange'),
      palette: EraPalette.fromJson(json.obj('palette', at: at), '$at.palette'),
      primarySource: Citation.fromJson(
          json.obj('primarySource', at: at), '$at.primarySource'),
      events: List<HistoryEvent>.unmodifiable(events),
      cover: cover == null ? null : AssetRef.fromJson(cover, '$at.cover'),
      sceneLayers: List<AssetRef>.unmodifiable(layers),
      characters: List<Character>.unmodifiable(characters),
      flagship: json['flagship'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Era &&
      other.schemaVersion == schemaVersion &&
      other.id == id &&
      other.slug == slug &&
      other.order == order &&
      other.period == period &&
      other.title == title &&
      other.kicker == kicker &&
      other.subtitle == subtitle &&
      other.overview == overview &&
      other.yearRange == yearRange &&
      other.palette == palette &&
      other.primarySource == primarySource &&
      other.cover == cover &&
      other.flagship == flagship &&
      _listEq(other.events, events) &&
      _listEq(other.sceneLayers, sceneLayers) &&
      _listEq(other.characters, characters);

  @override
  int get hashCode => Object.hash(
        schemaVersion,
        id,
        slug,
        order,
        period,
        title,
        kicker,
        subtitle,
        overview,
        yearRange,
        palette,
        primarySource,
        cover,
        flagship,
        Object.hashAll(events),
        Object.hashAll(sceneLayers),
        Object.hashAll(characters),
      );
}

bool _listEq<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
