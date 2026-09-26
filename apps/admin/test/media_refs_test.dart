import 'dart:convert';

import 'package:admin/api/cms_api_client.dart';
import 'package:admin/state/content_draft.dart';
import 'package:admin/util/media_refs.dart';
import 'package:admin/util/media_urls.dart';
import 'package:admin/util/person_asset_path.dart';
import 'package:flutter_test/flutter_test.dart';

ContentDraft _draftWith(Map<String, String> files) =>
    ContentDraft.fromLoad(ContentAtHead('sha', files));

void main() {
  group('collectMediaRefs', () {
    test('indexes a scene layer video alongside its still image', () {
      final draft = _draftWith({
        'content/index.json': jsonEncode({
          'eras': ['dien-bien-phu'],
        }),
        'content/people.json': jsonEncode({'people': <dynamic>[]}),
        'content/periods.json': jsonEncode({'periods': <dynamic>[]}),
        'content/eras/dien-bien-phu.json': jsonEncode({
          'title': {'en': 'Điện Biên Phủ'},
          'scene': {
            'layers': [
              {
                'id': 'sky',
                'flagship': 'eras/dien-bien-phu/scene/sky.png',
                'reduced': 'eras/dien-bien-phu/scene/sky.png',
                'video': 'eras/dien-bien-phu/cover.mp4',
              },
              {'id': 'motes', 'type': 'particles'},
            ],
          },
          'events': <dynamic>[],
        }),
      });

      final refs = collectMediaRefs(draft);
      expect(refs.containsKey('eras/dien-bien-phu/scene/sky.png'), isTrue);
      expect(refs.containsKey('eras/dien-bien-phu/cover.mp4'), isTrue);
      expect(refs['eras/dien-bien-phu/cover.mp4']!.single.toString(), contains('video'));
      // The particles layer has neither an image nor a video path.
      expect(refs.values.expand((u) => u).length, 2);
    });
  });

  group('isVideoPath', () {
    test('an .mp4 path is a video; an image path is not', () {
      expect(isVideoPath('eras/dien-bien-phu/cover.mp4'), isTrue);
      expect(isVideoPath('eras/dien-bien-phu/cover.png'), isFalse);
    });
  });

  group('personAssetPath', () {
    test('files under the first era already referencing the person', () {
      expect(
        personAssetPath(id: 'trung-trac', usedIn: ['hai-ba-trung', 'ba-trieu'], suffix: 'avatar'),
        'eras/hai-ba-trung/characters/trung-trac-avatar.png',
      );
    });

    test('a person used nowhere yet goes under people/', () {
      expect(
        personAssetPath(id: 'new-figure', usedIn: const [], suffix: 'full'),
        'people/new-figure-full.png',
      );
    });
  });
}
