// Writes `content/media-sources.json` — the record of exactly which
// original each served image was built from, so the next
// `tool/media_ledger.dart` run can tell what changed without downloading
// anything. Run once a publish (full or incremental) has actually
// succeeded; never speculatively.
//
// Usage: dart run tool/write_media_ledger.dart

import 'dart:convert';
import 'dart:io';

const kEncoderTag = 'webp-q85-m6'; // must match gen_media_manifest.dart

Future<void> main() async {
  exitCode = await _run();
}

Future<int> _run() async {
  final root = Directory.current;
  final contentDir = Directory('${root.path}/content');

  Map<String, dynamic> readJson(String rel) =>
      jsonDecode(File('${contentDir.path}/$rel').readAsStringSync()) as Map<String, dynamic>;

  final index = readJson('index.json');
  final slugs = <String>[
    for (final s in index['eras'] as List)
      if (s is String) s,
  ];
  final referenced = <String>{};
  for (final slug in slugs) {
    _collectMediaPaths(readJson('eras/$slug.json'), referenced);
  }
  _collectMediaPaths(readJson('people.json'), referenced);
  // Events live in their own registry since Cycle N — heroes included.
  _collectMediaPaths(readJson('events.json'), referenced);
  _collectMediaPaths(readJson('periods.json'), referenced);

  stdout.writeln('→ listing long-ky-sources…');
  final result = await Process.run('rclone', <String>[
    'lsjson',
    'r2:long-ky-sources',
    '--recursive',
    '--hash',
    '--no-modtime',
    '--no-mimetype',
    '--fast-list',
    '--s3-no-check-bucket',
  ]);
  if (result.exitCode != 0) {
    stderr.writeln('✗ rclone lsjson failed: ${result.stderr}');
    return 1;
  }
  final entries = jsonDecode(result.stdout as String) as List;
  final byPath = <String, Map<String, dynamic>>{
    for (final e in entries)
      if (!(e as Map<String, dynamic>)['Path'].toString().startsWith('_replaced/'))
        e['Path'] as String: e,
  };

  final files = <String, dynamic>{};
  final missing = <String>[];
  for (final path in referenced.toList()..sort()) {
    final src = byPath[path];
    if (src == null) {
      missing.add(path);
      continue;
    }
    files[path] = <String, dynamic>{
      'md5': (src['Hashes'] as Map?)?['md5'],
      'size': src['Size'],
    };
  }
  if (missing.isNotEmpty) {
    for (final m in missing) {
      stderr.writeln('✗ referenced but not in long-ky-sources: $m');
    }
    return 1;
  }

  final ledger = <String, dynamic>{
    'schemaVersion': 1,
    'encoderTag': kEncoderTag,
    'files': files,
  };
  File('${contentDir.path}/media-sources.json')
      .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(ledger)}\n');
  stdout.writeln('✓ wrote content/media-sources.json (${files.length} files)');
  return 0;
}

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
    if (_looksLikeMediaPath(node)) out.add(node);
  }
}

const _mediaExtensions = <String>{'.png', '.jpg', '.jpeg', '.webp', '.gif', '.mp4', '.geojson', '.pmtiles'};

bool _looksLikeMediaPath(String s) {
  final dot = s.lastIndexOf('.');
  if (dot == -1) return false;
  return _mediaExtensions.contains(s.substring(dot).toLowerCase());
}
