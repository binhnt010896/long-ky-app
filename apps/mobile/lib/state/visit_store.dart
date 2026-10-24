import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../screens/streets/street_data.dart';
import '../telemetry/telemetry.dart';
import 'narration_controller.dart';

/// What the reader has opened: the people, events and eras whose page they have
/// visited, as [VisitKey]s. It lights up the street map (a street is
/// discovered once any of its targets is here). Stored on the device only;
/// nothing about it is sent anywhere. Progress that only ever grows — a missed
/// day takes nothing away.
class VisitData {
  const VisitData({this.visited = const <String>{}, this.backfilled = false});

  final Set<String> visited;

  /// The one-time import from narration history has been done.
  final bool backfilled;
}

/// The visit persistence seam — file-backed in the app, in-memory in tests.
abstract class VisitStore {
  Future<VisitData> load();
  Future<void> save(VisitData data);
}

/// Same on-disk pattern as the other small stores; on web it keeps the set in
/// memory for the session only.
class FileVisitStore implements VisitStore {
  VisitData? _cached;

  static Future<File?> _file() async {
    if (kIsWeb) return null;
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/visits.json');
  }

  @override
  Future<VisitData> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final file = await _file();
      if (file == null || !file.existsSync()) return _cached = const VisitData();
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return _cached = const VisitData();
      final visited = raw['visited'];
      return _cached = VisitData(
        visited: visited is List ? visited.whereType<String>().toSet() : <String>{},
        backfilled: raw['backfilled'] == true,
      );
    } catch (e, s) {
      // Unreadable file: start over rather than fail the map.
      reportNonFatal(e, s, reason: 'FileVisitStore.load');
      return _cached = const VisitData();
    }
  }

  @override
  Future<void> save(VisitData data) async {
    _cached = data;
    try {
      final file = await _file();
      if (file == null) return;
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(<String, dynamic>{
        'visited': data.visited.toList()..sort(),
        'backfilled': data.backfilled,
      }));
      await tmp.rename(file.path);
    } catch (e, s) {
      // The in-memory copy still holds for this session.
      reportNonFatal(e, s, reason: 'FileVisitStore.save');
    }
  }
}

final visitStoreProvider = Provider<VisitStore>((ref) => FileVisitStore());

/// The [VisitKey] a page records when opened, or null for a location that is
/// not a person, event or era page. Pure.
///
/// An in-era person or event is opened at `/era/:slug/figure|event/:id`; a
/// standalone one at `/nhan-vat/:id` or `/su-kien/:id` (an in-era one never
/// reaches those: the router redirects before a location exists).
String? visitKeyForUri(Uri uri) {
  final s = uri.pathSegments;
  if (s.isEmpty) return null;
  switch (s.first) {
    case 'era':
      if (s.length == 2 || (s.length == 3 && s[2] == 'timeline')) {
        return VisitKey.era(s[1]);
      }
      if (s.length == 4 && s[2] == 'event') return VisitKey.event(s[3]);
      if (s.length == 4 && s[2] == 'figure') return VisitKey.person(s[3]);
      return null;
    case 'nhan-vat':
      return s.length == 2 ? VisitKey.person(s[1]) : null;
    case 'su-kien':
      return s.length == 2 ? VisitKey.event(s[1]) : null;
    default:
      return null;
  }
}

/// A narration key (`eras/<slug>`, `people/<id>`, `events/<id>`) as a
/// [VisitKey]. Playing a page's narration means the page was opened, so
/// existing readers start with the streets they have already earned.
String? visitKeyFromNarrationKey(String key) {
  final i = key.indexOf('/');
  if (i <= 0 || i == key.length - 1) return null;
  final id = key.substring(i + 1);
  return switch (key.substring(0, i)) {
    'eras' => VisitKey.era(id),
    'people' => VisitKey.person(id),
    'events' => VisitKey.event(id),
    _ => null,
  };
}

/// The streets a visit has just lit for the first time, so the page that
/// caused it can say so once (see StreetReverseChip).
class NewlyLit {
  const NewlyLit(this.key, this.streets);

  /// The [VisitKey] of the page opened.
  final String key;

  /// The streets that visit discovered (never already-discovered ones).
  final List<MappedStreet> streets;
}

final newlyLitProvider = StateProvider<NewlyLit?>((ref) => null);

class VisitedNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final store = ref.watch(visitStoreProvider);
    var data = await store.load();
    if (!data.backfilled) {
      final heard =
          (await ref.read(narrationStoreProvider).load()).heard;
      data = VisitData(
        visited: <String>{
          ...data.visited,
          for (final k in heard)
            if (visitKeyFromNarrationKey(k) case final v?) v,
        },
        backfilled: true,
      );
      await store.save(data);
    }
    return data.visited;
  }

  /// Records a visit. When it lights streets that were dark, publishes them on
  /// [newlyLitProvider].
  Future<void> record(String key) async {
    // The latest state, so two quick navigations can't both start from a stale set.
    final visited = state.valueOrNull ?? await future;
    if (visited.contains(key)) return;
    final next = <String>{...visited, key};
    state = AsyncData(next);
    await ref
        .read(visitStoreProvider)
        .save(VisitData(visited: next, backfilled: true));
    final mapping = await ref.read(streetMappingProvider.future).catchError(
          (Object _) => null,
        );
    if (mapping == null) return;
    final before = discoveredStreetIds(mapping.approved, visited);
    final after = discoveredStreetIds(mapping.approved, next);
    final lit = <MappedStreet>[
      for (final s in mapping.approved)
        if (after.contains(s.id) && !before.contains(s.id)) s,
    ];
    if (lit.isNotEmpty) {
      ref.read(newlyLitProvider.notifier).state = NewlyLit(key, lit);
    }
  }
}

final visitedProvider =
    AsyncNotifierProvider<VisitedNotifier, Set<String>>(VisitedNotifier.new);

/// The ids of the approved streets the reader has discovered.
final discoveredStreetsProvider = Provider<Set<String>>((ref) {
  final visited = ref.watch(visitedProvider).valueOrNull;
  final mapping = ref.watch(streetMappingProvider).valueOrNull;
  if (visited == null || mapping == null) return const <String>{};
  return discoveredStreetIds(mapping.approved, visited);
});

/// Records a visit on every navigation, from the router itself (a screen never
/// has to remember to). Mirrors RouteTelemetryObserver.
class VisitRecorder {
  VisitRecorder(this._router, this._record) {
    _router.routerDelegate.addListener(_onRouteChanged);
    _onRouteChanged();
  }

  final GoRouter _router;
  final void Function(String key) _record;
  String? _last;

  void _onRouteChanged() {
    final key =
        visitKeyForUri(_router.routerDelegate.currentConfiguration.uri);
    if (key == null || key == _last) return;
    _last = key;
    _record(key);
  }

  void dispose() => _router.routerDelegate.removeListener(_onRouteChanged);
}
