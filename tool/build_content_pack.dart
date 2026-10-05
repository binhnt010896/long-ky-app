// Builds one versioned content pack — index, people, periods, the media
// manifest, and every era's JSON, all in one file — plus a small `latest.json`
// pointer, for tool/publish_content.sh to upload. Refuses to build on stale or
// invalid content, so a broken publish never reaches phones.
//
// Usage: dart run tool/build_content_pack.dart [--only <file>]
//   --only <file>: incremental mode (Cycle K) — forwarded to
//   gen_media_manifest.dart --check --only <file>, so the staleness check
//   only needs the paths tool/media_ledger.dart found changed to be present
//   on disk (an incremental CI runner never downloads the rest). Omit for
//   a full-mode run, where every original is already present locally.
//
// Writes:
//   - build/pack/<version>.json   the pack itself
//   - build/pack/latest.json      { schemaVersion, version, sha256, path }
//   - content/content-version.json   { version } — commit this; it's bundled,
//     so the shipped app knows its own baseline version.

import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';
import 'package:crypto/crypto.dart';

/// Bump only if a pack's top-level shape changes in a way old app builds
/// couldn't handle; see ContentPack.parseAndValidate's schemaVersion gate.
const int kPackSchemaVersion = 1;

Future<void> main(List<String> args) async {
  String? onlyFile;
  final onlyIdx = args.indexOf('--only');
  if (onlyIdx != -1 && onlyIdx + 1 < args.length) onlyFile = args[onlyIdx + 1];
  exitCode = await _run(onlyFile: onlyFile);
}

Future<int> _run({String? onlyFile}) async {
  final root = Directory.current;

  stdout.writeln('→ validating content…');
  final validate = await Process.run(
      'dart', <String>['run', 'tool/validate_content.dart'],
      workingDirectory: root.path);
  stdout.write(validate.stdout);
  if (validate.exitCode != 0) {
    stderr.write(validate.stderr);
    stderr.writeln('✗ content validation failed — refusing to build a pack');
    return 1;
  }

  stdout.writeln('→ checking media manifest is up to date…');
  final manifestCheck = await Process.run(
      'dart',
      <String>[
        'run',
        'tool/gen_media_manifest.dart',
        '--check',
        if (onlyFile != null) ...['--only', onlyFile],
      ],
      workingDirectory: root.path);
  stdout.write(manifestCheck.stdout);
  if (manifestCheck.exitCode != 0) {
    stderr.write(manifestCheck.stderr);
    stderr.writeln(
        '✗ media manifest is stale — run tool/sync_media.sh first (publish_content.sh does this for you)');
    return 1;
  }

  final contentDir = Directory('${root.path}/content');
  Map<String, dynamic> readJson(String rel) =>
      jsonDecode(File('${contentDir.path}/$rel').readAsStringSync())
          as Map<String, dynamic>;

  final index = readJson('index.json');
  final people = readJson('people.json');
  final periods = readJson('periods.json');
  final media = readJson('media-manifest.json');

  final allSlugs = <String>[
    for (final s in index['eras'] as List)
      if (s is String) s,
  ];
  final rawEras = <String, Map<String, dynamic>>{
    for (final slug in allSlugs) slug: readJson('eras/$slug.json'),
  };
  // Events live in content/events.json and eras list them as `{ref}` items.
  // The pack keeps every era's events *inlined, with `order`* — the shape
  // every installed app build already parses — and carries the standalone
  // events (listed by no era) under a new key those builds never read.
  final eventsById = eventJsonById(readJson('events.json'));
  final allEras = <String, dynamic>{
    for (final e in rawEras.entries) e.key: inlineEraEvents(e.value, eventsById),
  };

  // Draft eras (see era.schema.json's `draft`) are still authored, valid
  // JSON on `main` — they just never go out over the air. Dropped here,
  // not earlier, so validation/referential-integrity checks above still
  // cover them while they're being written.
  final draftSlugs = <String>{
    for (final entry in allEras.entries)
      if (entry.value['draft'] == true) entry.key,
  };
  final slugs = allSlugs.where((s) => !draftSlugs.contains(s)).toList();
  final eras = <String, dynamic>{
    for (final slug in slugs) slug: allEras[slug],
  };
  final publishedIndex = <String, dynamic>{...index, 'eras': slugs};

  final version = _versionStamp(DateTime.now().toUtc());

  // Standalone = listed by no era at all, drafts included — an event only a
  // draft era lists must not leak out as a standalone one.
  final standaloneIds = standaloneEventIds(rawEras.values, eventsById.keys);

  // Street mappings (content/streets/<city>.json) ride in the pack so new
  // streets need no app release; the app still bundles a copy as its fallback.
  // aliases.json is a tooling input (street-name spellings), not a mapping.
  final streets = <String, dynamic>{};
  final streetsDir = Directory('${contentDir.path}/streets');
  if (streetsDir.existsSync()) {
    final files = streetsDir
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('.json') && !f.path.endsWith('/aliases.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final json = jsonDecode(f.readAsStringSync());
      if (json is Map<String, dynamic> && json['streets'] is List) {
        streets[json['city'] as String] = json;
      }
    }
  }

  final pack = <String, dynamic>{
    'schemaVersion': kPackSchemaVersion,
    'version': version,
    'index': publishedIndex,
    'people': people,
    'periods': periods,
    'media': media,
    'eras': eras,
    'standaloneEvents': <String, dynamic>{
      'schemaVersion': 1,
      'events': [for (final id in standaloneIds) eventsById[id]],
    },
    if (streets.isNotEmpty) 'streets': streets,
  };

  if (draftSlugs.isNotEmpty) {
    stdout.writeln('  excluding ${draftSlugs.length} draft era(s): ${draftSlugs.join(', ')}');
  }

  final packJson = jsonEncode(pack);
  final packDir = Directory('${root.path}/build/pack');
  packDir.createSync(recursive: true);
  final packFile = File('${packDir.path}/$version.json');
  packFile.writeAsStringSync(packJson);

  final sha256Hex = sha256.convert(utf8.encode(packJson)).toString();

  final latest = <String, dynamic>{
    'schemaVersion': kPackSchemaVersion,
    'version': version,
    'sha256': sha256Hex,
    'path': 'content/packs/$version.json',
  };
  File('${packDir.path}/latest.json')
      .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(latest)}\n');

  final contentVersionFile = File('${contentDir.path}/content-version.json');
  contentVersionFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(<String, dynamic>{'version': version})}\n');

  final sizeKb = packJson.length / 1024;
  stdout.writeln(
      '✓ built pack version $version · ${slugs.length} eras · ${standaloneIds.length} standalone events · ${sizeKb.toStringAsFixed(0)} KB · sha256 ${sha256Hex.substring(0, 12)}…');
  stdout.writeln(
      '  Remember to commit content/content-version.json so the next app build knows this baseline.');
  return 0;
}

/// `yyyyMMddHHmmss` as an int, e.g. `20260923153000` — strictly increasing
/// across publishes as long as they're more than a second apart.
int _versionStamp(DateTime utc) {
  String two(int n) => n.toString().padLeft(2, '0');
  return int.parse('${utc.year}${two(utc.month)}${two(utc.day)}'
      '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}');
}
