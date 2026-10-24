import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';

/// What the bundled content holds, read from `content/` itself, so a test can
/// state "every era and event" without hard-coding a count that the next
/// content pack would break.
class ContentCounts {
  ContentCounts._(this.eraCount, this.eraEventCount, this.standaloneIds);

  /// Eras listed in `content/index.json`.
  final int eraCount;

  /// Events across every era's list (a slot per era, as the screens count).
  final int eraEventCount;

  /// Registry events no era lists, in registry order.
  final List<String> standaloneIds;

  int get standaloneCount => standaloneIds.length;

  /// Every event the Global Timeline shows: era events plus standalone ones.
  int get totalEventCount => eraEventCount + standaloneCount;

  /// The Global Timeline's header line.
  String get timelineHeader => '$eraCount kỷ nguyên · $totalEventCount sự kiện';

  /// `flutter test` runs with `apps/mobile` as the working directory.
  static ContentCounts read({String root = '../../content'}) {
    Map<String, dynamic> json(String path) =>
        jsonDecode(File('$root/$path').readAsStringSync())
            as Map<String, dynamic>;

    final slugs = [for (final s in json('index.json')['eras'] as List) '$s'];
    final eras = [for (final s in slugs) json('eras/$s.json')];
    final byId = eventJsonById(json('events.json'));
    return ContentCounts._(
      slugs.length,
      eras.fold<int>(0, (n, e) => n + (e['events'] as List).length),
      standaloneEventIds(eras, byId.keys),
    );
  }
}
