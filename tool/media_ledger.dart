// Compares what content/ references against `content/media-sources.json`
// (the record of what's actually live, written by the last publish) and a
// live listing of the `long-ky-sources` bucket, to find the minimum set of
// media a publish needs to touch — see EXECUTION.md's Cycle K.
//
// No downloads: the source listing is a metadata-only `rclone lsjson`, and
// the ledger/content are both small JSON already on disk.
//
// Usage:
//   dart run tool/media_ledger.dart [--mode incremental|full]
//
// Writes, for tool/publish_content.sh / the workflow to consume:
//   build/media-plan.json           the full plan, machine-readable
//   build/media-changed-sources.txt source paths to download + convert
//   build/media-changed-keys.txt    served keys those produce (for upload)
//   build/media-removed-keys.txt    served keys to delete from the CDN
//
// Exit codes: 0 ok (even with nothing to do); 1 a referenced source is
// genuinely missing from long-ky-sources; 2 `full` is required (no ledger
// yet, or its encoderTag doesn't match — see gen_media_manifest.dart's
// kEncoderTag) but `--mode incremental` was requested anyway.

import 'dart:convert';
import 'dart:io';

const kEncoderTag = 'webp-q85-m6'; // must match gen_media_manifest.dart

Future<void> main(List<String> args) async {
  final modeIdx = args.indexOf('--mode');
  final mode = modeIdx != -1 && modeIdx + 1 < args.length ? args[modeIdx + 1] : 'incremental';
  exitCode = await _run(mode);
}

Future<int> _run(String mode) async {
  final root = Directory.current;
  final contentDir = Directory('${root.path}/content');
  final buildDir = Directory('${root.path}/build');
  buildDir.createSync(recursive: true);

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
  // Events live in their own registry since Cycle N — heroes included. Miss
  // this and every event hero looks unreferenced (an incremental publish
  // would then plan to delete them).
  _collectMediaPaths(readJson('events.json'), referenced);
  _collectMediaPaths(readJson('periods.json'), referenced);
  // Cycle M: a city street map's `geometry` GeoJSON is media like any other.
  final streetsDir = Directory('${contentDir.path}/streets');
  if (streetsDir.existsSync()) {
    for (final f in streetsDir.listSync().whereType<File>()) {
      final n = f.uri.pathSegments.last;
      if (n.endsWith('.json') && !n.startsWith('aliases')) {
        _collectMediaPaths(jsonDecode(f.readAsStringSync()), referenced);
      }
    }
  }

  final ledgerFile = File('${contentDir.path}/media-sources.json');
  final manifestFile = File('${contentDir.path}/media-manifest.json');
  Map<String, dynamic>? ledger;
  if (ledgerFile.existsSync()) {
    ledger = jsonDecode(ledgerFile.readAsStringSync()) as Map<String, dynamic>;
  }
  final ledgerStale = ledger == null || ledger['encoderTag'] != kEncoderTag;

  if (mode == 'incremental' && ledgerStale) {
    stderr.writeln(ledger == null
        ? '✗ no content/media-sources.json yet — run with --mode full once to create it.'
        : '✗ media-sources.json encoderTag ("${ledger['encoderTag']}") != current '
            '("$kEncoderTag") — run with --mode full once to re-baseline.');
    return 2;
  }

  stdout.writeln('→ listing long-ky-sources (metadata only, no download)…');
  final listed = await _listSources();

  final ledgerFiles =
      (ledger?['files'] as Map<String, dynamic>?)?.cast<String, dynamic>() ?? const {};
  final manifest = manifestFile.existsSync()
      ? (jsonDecode(manifestFile.readAsStringSync())
          as Map<String, dynamic>)['files'] as Map<String, dynamic>
      : const <String, dynamic>{};

  final added = <String>[];
  final changed = <String>[];
  final drifted = <String>[]; // manifest says served, CDN says otherwise
  final missing = <String>[];
  final unchanged = <String>[];

  for (final path in referenced.toList()..sort()) {
    final src = listed[path];
    if (src == null) {
      missing.add(path);
      continue;
    }
    final ledgerEntry = ledgerFiles[path] as Map<String, dynamic>?;
    if (mode == 'full' || ledgerEntry == null) {
      added.add(path);
    } else if (ledgerEntry['md5'] != src['md5']) {
      changed.add(path);
    } else {
      unchanged.add(path);
    }
  }

  // Something the manifest thinks is live but a served listing (passed via
  // stdin as newline keys, optional — see --served-list below) says isn't.
  // Kept simple: drifted detection is left to a future pass if it's ever
  // needed; today's rebuild-on-mismatch is covered by `full`.

  final removedKeys = <String>[];
  final referencedSet = referenced;
  for (final entry in manifest.entries) {
    if (!referencedSet.contains(entry.key)) {
      removedKeys.add((entry.value as Map<String, dynamic>)['key'] as String);
    }
  }

  final changedSources = [...added, ...changed, ...drifted]..sort();

  final plan = <String, dynamic>{
    'mode': mode,
    'referencedCount': referenced.length,
    'added': added,
    'changed': changed,
    'drifted': drifted,
    'unchanged': unchanged.length,
    'missing': missing,
    'removedKeys': removedKeys,
  };
  File('${buildDir.path}/media-plan.json')
      .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(plan)}\n');
  File('${buildDir.path}/media-changed-sources.txt')
      .writeAsStringSync('${changedSources.join('\n')}\n');
  File('${buildDir.path}/media-removed-keys.txt')
      .writeAsStringSync('${removedKeys.join('\n')}\n');

  stdout.writeln('✓ plan: ${added.length} added · ${changed.length} changed · '
      '${unchanged.length} unchanged · ${removedKeys.length} to remove · '
      '${missing.length} missing');

  if (missing.isNotEmpty) {
    for (final m in missing) {
      stderr.writeln('✗ referenced but not in long-ky-sources: $m');
    }
    return 1;
  }
  return 0;
}

/// `rclone lsjson --hash --no-modtime --no-mimetype --fast-list` on
/// `long-ky-sources`, excluding `_replaced/` backups — metadata only, no
/// object bodies transferred. Keyed by path, value has `md5` and `size`.
Future<Map<String, Map<String, dynamic>>> _listSources() async {
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
    throw ProcessException('rclone', const ['lsjson'], result.stderr as String);
  }
  final entries = jsonDecode(result.stdout as String) as List;
  final out = <String, Map<String, dynamic>>{};
  for (final e in entries) {
    final m = e as Map<String, dynamic>;
    final path = m['Path'] as String;
    if (path.startsWith('_replaced/')) continue;
    out[path] = <String, dynamic>{
      'md5': (m['Hashes'] as Map?)?['md5'],
      'size': m['Size'],
    };
  }
  return out;
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

const _mediaExtensions = <String>{'.png', '.jpg', '.jpeg', '.webp', '.gif', '.mp4', '.geojson'};

bool _looksLikeMediaPath(String s) {
  final dot = s.lastIndexOf('.');
  if (dot == -1) return false;
  return _mediaExtensions.contains(s.substring(dot).toLowerCase());
}
