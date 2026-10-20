import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// What the reader has decided about narration, persisted between launches.
class NarrationPrefs {
  const NarrationPrefs({
    this.autoplay = true,
    this.popupAsked = false,
    this.heard = const <String>{},
  });

  /// Whether opening an era/person/event for the first time starts its
  /// narration on its own.
  final bool autoplay;

  /// The one-time "keep autoplay?" question has been answered (or the reader
  /// set the switch themselves in Sảnh), so it is never asked again.
  final bool popupAsked;

  /// Narration keys (`eras/<slug>`, `people/<id>`, `events/<id>`) that have
  /// already been played once: autoplay only fires on a first visit.
  final Set<String> heard;

  NarrationPrefs copyWith({
    bool? autoplay,
    bool? popupAsked,
    Set<String>? heard,
  }) =>
      NarrationPrefs(
        autoplay: autoplay ?? this.autoplay,
        popupAsked: popupAsked ?? this.popupAsked,
        heard: heard ?? this.heard,
      );
}

abstract class NarrationStore {
  Future<NarrationPrefs> load();
  Future<void> save(NarrationPrefs prefs);
}

/// Same on-disk pattern as the language and tour stores; on web it lives in
/// memory only.
class FileNarrationStore implements NarrationStore {
  NarrationPrefs? _cached;

  static Future<File?> _file() async {
    if (kIsWeb) return null;
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/narration.json');
  }

  @override
  Future<NarrationPrefs> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final file = await _file();
      if (file == null || !file.existsSync()) return _cached = const NarrationPrefs();
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return _cached = const NarrationPrefs();
      final heard = raw['heard'];
      return _cached = NarrationPrefs(
        autoplay: raw['autoplay'] is bool ? raw['autoplay'] as bool : true,
        popupAsked: raw['popupAsked'] is bool ? raw['popupAsked'] as bool : false,
        heard: heard is List ? heard.whereType<String>().toSet() : <String>{},
      );
    } catch (_) {
      // Unreadable file: defaults beat failing.
      return _cached = const NarrationPrefs();
    }
  }

  @override
  Future<void> save(NarrationPrefs prefs) async {
    _cached = prefs;
    try {
      final file = await _file();
      if (file == null) return;
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(<String, dynamic>{
        'autoplay': prefs.autoplay,
        'popupAsked': prefs.popupAsked,
        'heard': prefs.heard.toList()..sort(),
      }));
      await tmp.rename(file.path);
    } catch (_) {
      // The in-memory copy still holds for this session.
    }
  }
}
