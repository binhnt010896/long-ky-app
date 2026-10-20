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
}
