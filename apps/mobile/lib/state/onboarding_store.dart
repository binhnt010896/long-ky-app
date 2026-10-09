import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Bump to show the Home coachmark tour again after a redesign: a reader is
/// "done" only if they finished or skipped *this* version.
const int kHomeTourVersion = 1;

/// Remembers whether the reader has already been through the first-run Home
/// tour. Mirrors `FileLangStore`'s on-disk pattern. On web it lives in memory
/// only, so a fresh tab always shows the tour.
abstract class OnboardingStore {
  Future<bool> homeTourSeen();
  Future<void> markHomeTourSeen();

  /// Forgets it, so the tour plays again (the About screen's replay row).
  Future<void> resetHomeTour();
}

class FileOnboardingStore implements OnboardingStore {
  bool? _cached;

  static Future<File?> _storeFile() async {
    if (kIsWeb) return null;
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/onboarding.json');
  }

  @override
  Future<bool> homeTourSeen() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final file = await _storeFile();
      if (file == null || !file.existsSync()) return _cached = false;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return _cached = false;
      final v = raw['homeTour'];
      return _cached = v is int && v >= kHomeTourVersion;
    } catch (_) {
      // Unreadable file: showing the tour once more beats failing.
      return _cached = false;
    }
  }

  @override
  Future<void> markHomeTourSeen() async {
    _cached = true;
    try {
      final file = await _storeFile();
      if (file != null) {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(
          jsonEncode(<String, dynamic>{'homeTour': kHomeTourVersion}),
        );
        await tmp.rename(file.path);
      }
    } catch (_) {
      // In-memory state still reflects it for this session.
    }
  }

  @override
  Future<void> resetHomeTour() async {
    _cached = false;
    try {
      final file = await _storeFile();
      if (file != null && file.existsSync()) await file.delete();
    } catch (_) {}
  }
}
