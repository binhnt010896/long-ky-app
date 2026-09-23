// Walks content/eras/*.json, content/people.json and content/periods.json for
// every referenced media path, converts each into a served WebP (or copies it
// unchanged if it can't be converted) into a staging dir, and writes:
//   - content/media-manifest.json  schema v2: { path: { key, v } }. `key` is
//     the served path (relative to the bucket's media/ prefix); `v` is a
//     10-hex cache-busting version derived from the source bytes + encoder
//     settings, so both a source edit and an encoder-settings change bump it.
//   - build/media/<key>             the staged, served files (webp/copied).
//   - build/media/.stamps.json      key -> v, so unchanged sources are
//     skipped on the next run (incremental).
//   - build/media-files.txt         one served key per line, the rclone
//     --files-from list for tool/sync_media.sh.
//
// Files the content doesn't reference (raw sources, .DS_Store, stray originals
// kept next to a restored image) are never staged or listed.
//
// Usage: dart run tool/gen_media_manifest.dart [--check]
//   --check: recompute versions in memory (no cwebp, no staging) and exit 1
//   if content/media-manifest.json would differ, without writing anything.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _mediaExtensions = <String>{
  '.png',
  '.jpg',
  '.jpeg',
  '.webp',
  '.gif',
  '.mp4',
};

/// Source extensions cwebp can convert. Everything else (already .webp, .gif,
/// .mp4) is copied byte-for-byte into staging.
const _convertibleExtensions = <String>{'.png', '.jpg', '.jpeg'};

/// Bumping this changes every served file's version, forcing a re-fetch on
/// every device — use it if the encoder settings below ever change.
const kEncoderTag = 'webp-q85-m6';

Future<void> main(List<String> args) async {
  exitCode = await _run(check: args.contains('--check'));
}

Future<int> _run({required bool check}) async {
  final root = Directory.current;
  final contentDir = Directory('${root.path}/content');
  final indexFile = File('${contentDir.path}/index.json');

  if (!indexFile.existsSync()) {
    stderr.writeln('✗ content manifest not found: ${indexFile.path}');
    return 1;
  }

  if (!check && !await _cwebpAvailable()) {
    stderr.writeln('✗ cwebp not found — brew install webp');
    return 1;
  }

  final jsonFiles = <File>[
    for (final slug in _erasFromIndex(indexFile))
      File('${contentDir.path}/eras/$slug.json'),
    File('${contentDir.path}/people.json'),
    File('${contentDir.path}/periods.json'),
  ];

  final referenced = <String>{};
  for (final f in jsonFiles) {
    if (!f.existsSync()) {
      stderr.writeln('✗ referenced content file not found: ${f.path}');
      return 1;
    }
    _collectMediaPaths(jsonDecode(f.readAsStringSync()), referenced);
  }

  final sortedPaths = referenced.toList()..sort();
  final entries = <String, _ManifestEntry>{};
  final missing = <String>[];
  var sourceBytes = 0;

  // Two distinct source paths can compute the same served key — e.g. a
  // converted `foo.png` -> `foo.webp` colliding with a hand-authored
  // `foo.webp` (an animated hero, say) referenced alongside it as a static
  // fallback. Detect that up front and disambiguate every source whose
  // extension changes on conversion by keeping its original extension in the
  // served key too (`foo.png.webp`), so every source path maps to a unique
  // file and nothing races or silently overwrites another asset.
  final keyOwners = <String, List<String>>{};
  for (final path in sortedPaths) {
    if (!File('${contentDir.path}/$path').existsSync()) continue;
    keyOwners.putIfAbsent(_servedKey(path), () => <String>[]).add(path);
  }
  final collidingPaths = <String>{
    for (final owners in keyOwners.values)
      if (owners.length > 1) ...owners,
  };

  for (final path in sortedPaths) {
    final file = File('${contentDir.path}/$path');
    if (!file.existsSync()) {
      missing.add(path);
      continue;
    }
    final bytes = file.readAsBytesSync();
    sourceBytes += bytes.length;
    final key = collidingPaths.contains(path) && _isConvertible(path)
        ? '$path.webp'
        : _servedKey(path);
    final v = md5
        .convert(<int>[...bytes, ...utf8.encode(kEncoderTag)])
        .toString()
        .substring(0, 10);
    entries[path] = _ManifestEntry(key: key, v: v);
  }

  // Even after disambiguation, two source paths must never land on the same
  // served key — fail loudly rather than let one silently overwrite another.
  final finalOwners = <String, List<String>>{};
  for (final e in entries.entries) {
    finalOwners.putIfAbsent(e.value.key, () => <String>[]).add(e.key);
  }
  for (final owners in finalOwners.values) {
    if (owners.length > 1) {
      stderr.writeln('✗ served-key collision: ${owners.join(' vs ')}');
      return 1;
    }
  }

  final manifest = <String, Object?>{
    'schemaVersion': 2,
    'files': <String, Object?>{
      for (final e in entries.entries)
        e.key: <String, Object?>{'key': e.value.key, 'v': e.value.v},
    },
  };
  final encoder = const JsonEncoder.withIndent('  ');
  final manifestJson = '${encoder.convert(manifest)}\n';

  final manifestFile = File('${contentDir.path}/media-manifest.json');

  if (check) {
    final current =
        manifestFile.existsSync() ? manifestFile.readAsStringSync() : '';
    if (current != manifestJson) {
      stderr.writeln('✗ content/media-manifest.json is stale — run:');
      stderr.writeln('  dart run tool/gen_media_manifest.dart');
      return 1;
    }
    stdout.writeln('✓ content/media-manifest.json is up to date');
    return 0;
  }

  manifestFile.writeAsStringSync(manifestJson);

  final buildDir = Directory('${root.path}/build');
  final stagingDir = Directory('${buildDir.path}/media');
  stagingDir.createSync(recursive: true);
  final stampsFile = File('${stagingDir.path}/.stamps.json');
  final stamps = <String, String>{
    if (stampsFile.existsSync())
      for (final e
          in (jsonDecode(stampsFile.readAsStringSync()) as Map<String, dynamic>)
              .entries)
        e.key: e.value as String,
  };

  var converted = 0;
  var skipped = 0;
  var processed = 0;
  final total = entries.length;
  final newStamps = <String, String>{};

  // A small worker pool over the entry list; each worker pulls the next
  // index off a shared cursor so slow conversions don't block fast copies.
  final work = entries.entries.toList();
  var cursor = 0;
  final poolSize =
      Platform.numberOfProcessors.clamp(1, 6);

  Future<void> runOne(String sourcePath, _ManifestEntry entry) async {
    final outFile = File('${stagingDir.path}/${entry.key}');
    if (stamps[entry.key] == entry.v && outFile.existsSync()) {
      newStamps[entry.key] = entry.v;
      skipped++;
    } else {
      outFile.parent.createSync(recursive: true);
      final srcFile = File('${contentDir.path}/$sourcePath');
      if (_isConvertible(sourcePath)) {
        final result = await Process.run('cwebp', <String>[
          '-quiet',
          '-q',
          '85',
          '-m',
          '6',
          '-mt',
          '-metadata',
          'none',
          srcFile.path,
          '-o',
          outFile.path,
        ]);
        if (result.exitCode != 0) {
          stderr.writeln('✗ cwebp failed on $sourcePath: ${result.stderr}');
          exit(1);
        }
        converted++;
      } else {
        await srcFile.copy(outFile.path);
        converted++;
      }
      newStamps[entry.key] = entry.v;
    }
    processed++;
    if (processed % 25 == 0 || processed == total) {
      stdout.writeln('  … $processed / $total');
    }
  }

  Future<void> worker() async {
    while (true) {
      final int i;
      if (cursor >= work.length) return;
      i = cursor++;
      final e = work[i];
      await runOne(e.key, e.value);
    }
  }

  await Future.wait(<Future<void>>[for (var i = 0; i < poolSize; i++) worker()]);

  stampsFile.writeAsStringSync('${encoder.convert(newStamps)}\n');

  File('${buildDir.path}/media-files.txt').writeAsStringSync(
      '${entries.values.map((e) => e.key).toList().join('\n')}\n');

  for (final path in missing) {
    stderr.writeln('⚠ referenced media not found on disk: $path');
  }

  var servedBytes = 0;
  for (final e in entries.values) {
    final f = File('${stagingDir.path}/${e.key}');
    if (f.existsSync()) servedBytes += f.lengthSync();
  }

  final srcGb = sourceBytes / 1e9;
  final servedGb = servedBytes / 1e9;
  stdout.writeln(
      '✓ ${entries.length} files · source ${srcGb.toStringAsFixed(2)} GB → served ${servedGb.toStringAsFixed(2)} GB '
      '(${converted} converted, ${skipped} unchanged) · ${missing.length} missing');
  return 0;
}

class _ManifestEntry {
  _ManifestEntry({required this.key, required this.v});
  final String key;
  final String v;
}

Future<bool> _cwebpAvailable() async {
  try {
    final result = await Process.run('cwebp', <String>['-version']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

bool _isConvertible(String path) {
  final dot = path.lastIndexOf('.');
  if (dot == -1) return false;
  return _convertibleExtensions.contains(path.substring(dot).toLowerCase());
}

/// The served key for a source path: convertible images become `.webp`;
/// everything else (already-webp, gif, mp4) keeps its extension.
String _servedKey(String path) {
  if (!_isConvertible(path)) return path;
  final dot = path.lastIndexOf('.');
  return '${path.substring(0, dot)}.webp';
}

List<String> _erasFromIndex(File indexFile) {
  final json = jsonDecode(indexFile.readAsStringSync());
  if (json is! Map<String, dynamic> || json['eras'] is! List) return const [];
  return <String>[
    for (final s in json['eras'] as List)
      if (s is String) s,
  ];
}

/// Recursively collects every string value that looks like a media path.
void _collectMediaPaths(Object? node, Set<String> out) {
  if (node is Map) {
    for (final v in node.values) {
      _collectMediaPaths(v, out);
    }
  } else if (node is List) {
    for (final v in node) {
      _collectMediaPaths(v, out);
    }
  } else if (node is String) {
    final dot = node.lastIndexOf('.');
    if (dot != -1 &&
        _mediaExtensions.contains(node.substring(dot).toLowerCase())) {
      out.add(node);
    }
  }
}
