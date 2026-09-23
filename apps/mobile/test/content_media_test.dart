import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/theme/content_assets.dart';

void main() {
  setUp(() => ContentMedia.debugSetEntries(const <String, ContentMediaEntry>{}));

  test('url has no media/ remap or query when the path is not in the manifest',
      () {
    expect(
      ContentMedia.url('eras/hong-bang/cover.png'),
      '$kContentMediaBase/media/eras/hong-bang/cover.png',
    );
  });

  test('url resolves to the served .webp key with ?v=<hash>', () {
    ContentMedia.debugSetEntries(const <String, ContentMediaEntry>{
      'eras/hong-bang/cover.png':
          ContentMediaEntry(key: 'eras/hong-bang/cover.webp', v: 'abc1234567'),
    });
    expect(
      ContentMedia.url('eras/hong-bang/cover.png'),
      '$kContentMediaBase/media/eras/hong-bang/cover.webp?v=abc1234567',
    );
  });

  test('a path with diacritics or spaces is percent-encoded', () {
    final url = ContentMedia.url('eras/đại-thắng/covér image.png');
    expect(url, isNot(contains(' ')));
    expect(url, isNot(contains('đ')));
    expect(url, startsWith('$kContentMediaBase/media/'));
  });

  test('applyManifest parses schema v1 (path is its own served key)', () {
    ContentMedia.applyManifest(const <String, dynamic>{
      'schemaVersion': 1,
      'files': <String, dynamic>{'eras/au-lac/cover.png': 'deadbeef01'},
    });
    expect(
      ContentMedia.url('eras/au-lac/cover.png'),
      '$kContentMediaBase/media/eras/au-lac/cover.png?v=deadbeef01',
    );
  });

  test('applyManifest parses schema v2 (key + v per entry)', () {
    ContentMedia.applyManifest(const <String, dynamic>{
      'schemaVersion': 2,
      'files': <String, dynamic>{
        'eras/au-lac/cover.png': <String, dynamic>{
          'key': 'eras/au-lac/cover.webp',
          'v': 'cafe123456',
        },
      },
    });
    expect(
      ContentMedia.url('eras/au-lac/cover.png'),
      '$kContentMediaBase/media/eras/au-lac/cover.webp?v=cafe123456',
    );
  });
}
