import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Persists the "Gửi thống kê ẩn danh" / "Share anonymous usage stats" switch
/// in Về Long Ký. Default is **on** (no first-run prompt — see the
/// delicate-UI rule); flipping it off calls [Telemetry.setEnabled] before the
/// next event and survives restarts. Mirrors `QuizStore`'s on-disk pattern.
abstract class TelemetrySettingsStore {
  Future<bool> load();
  Future<void> setEnabled(bool enabled);
}

class FileTelemetrySettingsStore implements TelemetrySettingsStore {
  bool? _cached;

  static Future<File?> _storeFile() async {
    if (kIsWeb) return null;
    final dir = await getApplicationSupportDirectory();
    final telemetryDir = Directory('${dir.path}/telemetry');
    if (!telemetryDir.existsSync()) telemetryDir.createSync(recursive: true);
    return File('${telemetryDir.path}/settings.json');
  }

  @override
  Future<bool> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final file = await _storeFile();
      if (file == null || !file.existsSync()) return _cached = true;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return _cached = true;
      final enabled = raw['enabled'];
      return _cached = enabled is bool ? enabled : true;
    } catch (_) {
      // A corrupted or unreadable file is not worth failing over — default on.
      return _cached = true;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    _cached = enabled;
    try {
      final file = await _storeFile();
      if (file != null) {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(jsonEncode(<String, dynamic>{'enabled': enabled}));
        await tmp.rename(file.path);
      }
    } catch (_) {
      // In-memory _cached already reflects the choice even if the write
      // failed — the session stays consistent even without persistence.
    }
  }
}
