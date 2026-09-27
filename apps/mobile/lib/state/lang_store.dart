import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Persists the VI/EN reading-language choice (the Sảnh's [LangToggle]), so a
/// relaunch reopens in the language the reader last chose. Vietnamese is
/// canonical and stays the default when nothing has been saved yet. Mirrors
/// `FileTelemetrySettingsStore`'s on-disk pattern.
abstract class LangStore {
  Future<Lang> load();
  Future<void> save(Lang lang);
}

class FileLangStore implements LangStore {
  Lang? _cached;

  static Future<File?> _storeFile() async {
    if (kIsWeb) return null;
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/lang.json');
  }

  @override
  Future<Lang> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final file = await _storeFile();
      if (file == null || !file.existsSync()) return _cached = Lang.vi;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return _cached = Lang.vi;
      return _cached = raw['lang'] == 'en' ? Lang.en : Lang.vi;
    } catch (_) {
      // A corrupted or unreadable file is not worth failing over — default to
      // the canonical language.
      return _cached = Lang.vi;
    }
  }

  @override
  Future<void> save(Lang lang) async {
    _cached = lang;
    try {
      final file = await _storeFile();
      if (file != null) {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(
            jsonEncode(<String, dynamic>{'lang': lang == Lang.en ? 'en' : 'vi'}));
        await tmp.rename(file.path);
      }
    } catch (_) {
      // In-memory _cached already reflects the choice even if the write
      // failed — the session stays consistent even without persistence.
    }
  }
}
