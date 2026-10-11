import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Bump when the street map's tour gains a step: a reader is "done" only if
/// they finished or skipped *this* version. Each step carries the version that
/// introduced it (`MapTourStep.since`), so a returning reader is shown only
/// the steps they have not seen.
///
/// 1 — tap a street, open its card. 2 — the filter.
const int kStreetTourVersion = 2;

/// Same, for the territory atlas's tour.
const int kAtlasTourVersion = 1;

/// Remembers whether the reader has already seen one screen's coachmark tour.
/// Same on-disk pattern as the language and Home-tour stores; on web it is in
/// memory only, so a fresh tab shows the tour.
abstract class TourStore {
  Future<bool> seen();
  Future<void> markSeen();

  /// The tour version the reader last finished or skipped; 0 = never. Stores
  /// that only know "seen" report a seen tour as fully seen.
  Future<int> seenVersion() async => await seen() ? 0x7fffffff : 0;
}

typedef StreetTourStore = TourStore;
typedef AtlasTourStore = TourStore;

class FileTourStore implements TourStore {
  FileTourStore({required this.fileName, required this.version});

  /// e.g. `street_tour.json`, inside the app-support directory.
  final String fileName;
  final int version;
  int? _cached;

  Future<File?> _file() async {
    if (kIsWeb) return null;
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$fileName');
  }

  @override
  Future<bool> seen() async => await seenVersion() >= version;

  @override
  Future<int> seenVersion() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final file = await _file();
      if (file == null || !file.existsSync()) return _cached = 0;
      final raw = jsonDecode(await file.readAsString());
      final v = raw is Map<String, dynamic> ? raw['version'] : null;
      return _cached = v is int ? v : 0;
    } catch (_) {
      // Unreadable file: showing the tour once more beats failing.
      return _cached = 0;
    }
  }

  @override
  Future<void> markSeen() async {
    _cached = version;
    try {
      final file = await _file();
      if (file != null) {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(
          jsonEncode(<String, dynamic>{'version': version}),
        );
        await tmp.rename(file.path);
      }
    } catch (_) {
      // The in-memory flag still holds for this session.
    }
  }
}

final streetTourStoreProvider = Provider<StreetTourStore>(
  (ref) =>
      FileTourStore(fileName: 'street_tour.json', version: kStreetTourVersion),
);

final atlasTourStoreProvider = Provider<AtlasTourStore>(
  (ref) =>
      FileTourStore(fileName: 'atlas_tour.json', version: kAtlasTourVersion),
);
