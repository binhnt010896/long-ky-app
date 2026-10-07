import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Bump to show the street map's coachmarks again after a redesign: a reader is
/// "done" only if they finished or skipped *this* version.
const int kStreetTourVersion = 1;

/// Remembers whether the reader has already seen the street map's two-step
/// coachmark tour. Same on-disk pattern as the language and Home-tour stores;
/// on web it is in memory only, so a fresh tab shows the tour.
abstract class StreetTourStore {
  Future<bool> seen();
  Future<void> markSeen();
}

class FileStreetTourStore implements StreetTourStore {
  bool? _cached;

  static Future<File?> _file() async {
    if (kIsWeb) return null;
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/street_tour.json');
  }

  @override
  Future<bool> seen() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final file = await _file();
      if (file == null || !file.existsSync()) return _cached = false;
      final raw = jsonDecode(await file.readAsString());
      final v = raw is Map<String, dynamic> ? raw['version'] : null;
      return _cached = v is int && v >= kStreetTourVersion;
    } catch (_) {
      // Unreadable file: showing the tour once more beats failing.
      return _cached = false;
    }
  }

  @override
  Future<void> markSeen() async {
    _cached = true;
    try {
      final file = await _file();
      if (file != null) {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(jsonEncode(<String, dynamic>{'version': kStreetTourVersion}));
        await tmp.rename(file.path);
      }
    } catch (_) {
      // The in-memory flag still holds for this session.
    }
  }
}

final streetTourStoreProvider =
    Provider<StreetTourStore>((ref) => FileStreetTourStore());
