// Walks content/eras/*.json, content/people.json and content/periods.json for
// every referenced media path, and writes:
//   - content/media-manifest.json  { path: first-10-hex-of-md5 }, for the app
//     to cache-bust URLs with `?v=<hash>`.
//   - build/media-files.txt        one content-relative path per line, the
//     rclone --files-from list for tool/sync_media.sh.
//
// Files the content doesn't reference (raw sources, .DS_Store, stray originals
// kept next to a restored image) are never listed, so they're never uploaded.
//
// Usage: dart run tool/gen_media_manifest.dart [--check]
//   --check: regenerate in memory and exit 1 if content/media-manifest.json
//   would differ, without writing anything. Not wired into DoD; a helper for
//   later CI.

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
  final versions = <String, String>{};
  final existing = <String>[];
  final missing = <String>[];
  var totalBytes = 0;

  for (final path in sortedPaths) {
    final file = File('${contentDir.path}/$path');
    if (!file.existsSync()) {
      missing.add(path);
      continue;
    }
    final bytes = file.readAsBytesSync();
    totalBytes += bytes.length;
    versions[path] = md5.convert(bytes).toString().substring(0, 10);
    existing.add(path);
  }

  final manifest = <String, Object?>{
    'schemaVersion': 1,
    'files': versions,
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
  if (!buildDir.existsSync()) buildDir.createSync(recursive: true);
  File('${buildDir.path}/media-files.txt')
      .writeAsStringSync('${existing.join('\n')}\n');

  for (final path in missing) {
    stderr.writeln('⚠ referenced media not found on disk: $path');
  }

  final gb = totalBytes / 1e9;
  stdout.writeln(
      '✓ ${existing.length} files · ${gb.toStringAsFixed(2)} GB · ${missing.length} missing');
  return 0;
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
