import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Bump when the Home tour gains a step: a reader is "done" only if they
/// finished or skipped *this* version. Each step carries the version that
/// introduced it (`CoachStep.since`), so a returning reader is shown only the
/// steps they have not seen.
///
/// 1 — welcome, eras, rail, timeline, Sảnh. 2 — the street map.
const int kHomeTourVersion = 2;

/// How many times the event page's "swipe to browse" hint is shown before it
/// stays away for good.
const int kSwipeHintShows = 3;

/// Remembers whether the reader has already been through the first-run Home
/// tour, and whether they have opened the Sảnh since it grew the street map.
/// Mirrors `FileLangStore`'s on-disk pattern. On web it lives in memory only,
/// so a fresh tab always shows the tour.
abstract class OnboardingStore {
  /// The tour version the reader last finished or skipped; 0 = never.
  Future<int> homeTourVersion();

  /// Finished or skipped the *current* tour version.
  Future<bool> homeTourSeen();
  Future<void> markHomeTourSeen();

  /// Forgets it, so the tour plays again (the About screen's replay row).
  Future<void> resetHomeTour();

  /// Whether the Sảnh has been opened; until then the Home seal wears a "new"
  /// dot, since the street map lives behind it.
  Future<bool> sanhVisited();
  Future<void> markSanhVisited();

  /// Ids of Home chrome buttons the reader has tapped at least once (see
  /// `HomeChromeButton`); an id missing here wears a red "unseen" dot.
  Future<Set<String>> seenChrome();
  Future<void> markChromeSeen(String id);

  /// How many times the event page's swipe hint has been shown.
  Future<int> swipeHintCount();
  Future<void> markSwipeHintShown();
}

class FileOnboardingStore implements OnboardingStore {
  Map<String, dynamic>? _cached;

  static Future<File?> _storeFile() async {
    if (kIsWeb) return null;
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/onboarding.json');
  }

  Future<Map<String, dynamic>> _read() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final file = await _storeFile();
      if (file == null || !file.existsSync()) return _cached = <String, dynamic>{};
      final raw = jsonDecode(await file.readAsString());
      return _cached = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    } catch (_) {
      // Unreadable file: showing the tour once more beats failing.
      return _cached = <String, dynamic>{};
    }
  }

  Future<void> _write(Map<String, dynamic> data) async {
    _cached = data;
    try {
      final file = await _storeFile();
      if (file != null) {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(jsonEncode(data));
        await tmp.rename(file.path);
      }
    } catch (_) {
      // In-memory state still reflects it for this session.
    }
  }

  @override
  Future<int> homeTourVersion() async {
    final v = (await _read())['homeTour'];
    return v is int ? v : 0;
  }

  @override
  Future<bool> homeTourSeen() async => await homeTourVersion() >= kHomeTourVersion;

  @override
  Future<void> markHomeTourSeen() async =>
      _write(<String, dynamic>{...await _read(), 'homeTour': kHomeTourVersion});

  @override
  Future<void> resetHomeTour() async {
    final data = <String, dynamic>{...await _read()}..remove('homeTour');
    await _write(data);
  }

  @override
  Future<bool> sanhVisited() async => (await _read())['sanhVisited'] == true;

  @override
  Future<void> markSanhVisited() async =>
      _write(<String, dynamic>{...await _read(), 'sanhVisited': true});

  @override
  Future<Set<String>> seenChrome() async {
    final v = (await _read())['seenChrome'];
    return v is List ? v.whereType<String>().toSet() : <String>{};
  }

  @override
  Future<void> markChromeSeen(String id) async {
    final seen = await seenChrome();
    if (!seen.add(id)) return;
    await _write(<String, dynamic>{
      ...await _read(),
      'seenChrome': seen.toList()..sort(),
    });
  }

  @override
  Future<int> swipeHintCount() async {
    final v = (await _read())['swipeHint'];
    return v is int ? v : 0;
  }

  @override
  Future<void> markSwipeHintShown() async => _write(<String, dynamic>{
        ...await _read(),
        'swipeHint': await swipeHintCount() + 1,
      });

  /// The one-time carry-over into [seenChrome] for readers who had the app
  /// before the red dots existed: someone who has already opened the street
  /// map ([streetMapOpened]) doesn't need a dot nudging them towards it. Runs
  /// once per install (a flag in the file), so after that only a tap on the
  /// button clears its dot. Returns the seen set, carried over or not.
  Future<Set<String>> carryOverChrome({required bool streetMapOpened}) async {
    final data = await _read();
    if (data['chromeCarriedOver'] == true) return seenChrome();
    final seen = await seenChrome();
    if (streetMapOpened) seen.add(kStreetsChromeId);
    await _write(<String, dynamic>{
      ...data,
      'seenChrome': seen.toList()..sort(),
      'chromeCarriedOver': true,
    });
    return seen;
  }
}

/// The street-map button's id in [OnboardingStore.seenChrome] — the same value
/// as `HomeChromeButton.streets` (kept here so the store needs no providers).
const String kStreetsChromeId = 'streets';
