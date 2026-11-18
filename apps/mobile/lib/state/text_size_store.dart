import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// The reader's own text size, on top of the phone's system setting.
enum ReaderTextSize {
  standard(1.0),
  large(1.15),
  larger(1.3);

  const ReaderTextSize(this.factor);

  /// Multiplies the system text scale.
  final double factor;
}

/// The most the app's text is ever scaled (system setting × [ReaderTextSize]).
/// Past this the chrome — top bars, the Home hero — stops fitting a phone, so
/// the largest accessibility sizes are held here rather than left to clip.
const double kMaxTextScale = 1.5;

/// The combined text scale for a system scale of [system] and the reader's
/// [size], held to [kMaxTextScale]. Pure.
double effectiveTextScale(double system, ReaderTextSize size) =>
    (system * size.factor).clamp(0.85, kMaxTextScale);

/// Persists the text-size choice. Mirrors `FileLangStore`'s on-disk pattern;
/// on web it lives in memory only.
abstract class TextSizeStore {
  Future<ReaderTextSize> load();
  Future<void> save(ReaderTextSize size);
}

class FileTextSizeStore implements TextSizeStore {
  ReaderTextSize? _cached;

  static Future<File?> _storeFile() async {
    if (kIsWeb) return null;
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/text_size.json');
  }

  @override
  Future<ReaderTextSize> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final file = await _storeFile();
      if (file == null || !file.existsSync()) {
        return _cached = ReaderTextSize.standard;
      }
      final raw = jsonDecode(await file.readAsString());
      final name = raw is Map<String, dynamic> ? raw['size'] : null;
      return _cached = ReaderTextSize.values.firstWhere(
        (s) => s.name == name,
        orElse: () => ReaderTextSize.standard,
      );
    } catch (_) {
      // Unreadable file: the standard size beats failing.
      return _cached = ReaderTextSize.standard;
    }
  }

  @override
  Future<void> save(ReaderTextSize size) async {
    _cached = size;
    try {
      final file = await _storeFile();
      if (file != null) {
        final tmp = File('${file.path}.tmp');
        await tmp
            .writeAsString(jsonEncode(<String, dynamic>{'size': size.name}));
        await tmp.rename(file.path);
      }
    } catch (_) {
      // The in-memory copy still holds for this session.
    }
  }
}

final textSizeStoreProvider =
    Provider<TextSizeStore>((ref) => FileTextSizeStore());

/// The reader's text size. main.dart overrides the initial value with the
/// saved one; the Sảnh's settings change it (and persist it).
final textSizeProvider =
    StateProvider<ReaderTextSize>((ref) => ReaderTextSize.standard);
