// Builds one versioned content pack — index, people, periods, the media
// manifest, and every era's JSON, all in one file — plus a small `latest.json`
// pointer, for tool/publish_content.sh to upload. Refuses to build on stale or
// invalid content, so a broken publish never reaches phones.
//
// Usage: dart run tool/build_content_pack.dart
//
// Writes:
//   - build/pack/<version>.json   the pack itself
//   - build/pack/latest.json      { schemaVersion, version, sha256, path }
//   - content/content-version.json   { version } — commit this; it's bundled,
//     so the shipped app knows its own baseline version.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Bump only if a pack's top-level shape changes in a way old app builds
/// couldn't handle; see ContentPack.parseAndValidate's schemaVersion gate.
const int kPackSchemaVersion = 1;

Future<void> main() async {
  exitCode = await _run();
}

Future<int> _run() async {
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
      'dart', <String>['run', 'tool/gen_media_manifest.dart', '--check'],
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

  final slugs = <String>[
    for (final s in index['eras'] as List)
      if (s is String) s,
  ];
  final eras = <String, dynamic>{
    for (final slug in slugs) slug: readJson('eras/$slug.json'),
  };

  final version = _versionStamp(DateTime.now().toUtc());

  final pack = <String, dynamic>{
    'schemaVersion': kPackSchemaVersion,
    'version': version,
    'index': index,
    'people': people,
    'periods': periods,
    'media': media,
    'eras': eras,
  };

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
      '✓ built pack version $version · ${slugs.length} eras · ${sizeKb.toStringAsFixed(0)} KB · sha256 ${sha256Hex.substring(0, 12)}…');
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
