/// Test support: a [ContentSource] over the repo's real `content/` directory.
///
/// Not part of `core_content.dart` — the app never imports it, so `dart:io`
/// stays out of every app build. The runtime uses [BundledContentSource]
/// (an AssetBundle); this gives a test the same behaviour, refs inlined and
/// standalone events included, without registering Flutter assets.
library;

import 'dart:convert';
import 'dart:io';

import 'package:core_domain/core_domain.dart';

import 'src/content_source.dart';

class DiskContentSource implements ContentSource {
  DiskContentSource(this.root);

  final Directory root;

  File _file(String rel) => File('${root.path}/$rel');

  Map<String, Map<String, dynamic>> _events() {
    final f = _file('events.json');
    if (!f.existsSync()) return const <String, Map<String, dynamic>>{};
    return eventJsonById(
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
  }

  @override
  Future<List<String>> availableSlugs() async => Directory('${root.path}/eras')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
      .toList();

  @override
  Future<String> loadEraJson(String slug) async {
    final file = _file('eras/$slug.json');
    if (!file.existsSync()) {
      throw ContentSourceException('era not found on disk: $slug');
    }
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return jsonEncode(inlineEraEvents(decoded, _events()));
  }

  @override
  Future<String> loadPeopleJson() async => _file('people.json').readAsString();

  @override
  Future<String> loadPeriodsJson() async =>
      _file('periods.json').readAsString();

  @override
  Future<String> loadStandaloneEventsJson() async {
    final all = _events();
    final eras = <Map<String, dynamic>>[
      for (final slug in await availableSlugs())
        jsonDecode(_file('eras/$slug.json').readAsStringSync())
            as Map<String, dynamic>,
    ];
    return jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'events': [for (final id in standaloneEventIds(eras, all.keys)) all[id]],
    });
  }
}
