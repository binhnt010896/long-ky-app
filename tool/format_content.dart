// Formats (or, with --check, just checks) every content/**/*.json file to
// the canonical layout — see ContentFormatter in packages/core_domain. Never
// touches content/**.png etc.
//
// Usage:
//   dart run tool/format_content.dart          # rewrite files in place
//   dart run tool/format_content.dart --check  # exit 1 if any file would
//                                               # change, without writing
//                                               # anything (CI)

import 'dart:io';

import 'package:core_domain/core_domain.dart';

Future<void> main(List<String> args) async {
  exitCode = await _run(check: args.contains('--check'));
}

Future<int> _run({required bool check}) async {
  final contentDir = Directory('${Directory.current.path}/content');
  if (!contentDir.existsSync()) {
    stderr.writeln('✗ content/ not found (run from the repo root)');
    return 1;
  }

  final files = contentDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final changed = <String>[];
  var invalid = false;

  for (final file in files) {
    final relPath = file.path.substring(Directory.current.path.length + 1);
    final original = await file.readAsString();
    final String canonical;
    try {
      canonical = ContentFormatter.reformat(original);
    } catch (e) {
      stderr.writeln('✗ $relPath: invalid JSON ($e)');
      invalid = true;
      continue;
    }
    if (canonical != original) {
      changed.add(relPath);
      if (!check) await file.writeAsString(canonical);
    }
  }

  if (invalid) return 1;

  if (check) {
    if (changed.isEmpty) {
      stdout.writeln('✓ all ${files.length} content JSON file(s) are canonically formatted');
      return 0;
    }
    stderr.writeln('✗ ${changed.length} file(s) not canonically formatted:');
    for (final p in changed) {
      stderr.writeln('    $p');
    }
    stderr.writeln('  Run: dart run tool/format_content.dart');
    return 1;
  }

  stdout.writeln(changed.isEmpty
      ? 'Already canonical — nothing to do.'
      : 'Reformatted ${changed.length} of ${files.length} file(s):');
  for (final p in changed) {
    stdout.writeln('  $p');
  }
  return 0;
}
