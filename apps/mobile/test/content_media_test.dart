import 'package:flutter_test/flutter_test.dart';
import 'package:viet_su/theme/content_assets.dart';

void main() {
  setUp(() => ContentMedia.debugSetVersions(const <String, String>{}));

  test('url has no query when the path is not in the manifest', () {
    expect(
      ContentMedia.url('eras/hong-bang/cover.png'),
      '$kContentMediaBase/eras/hong-bang/cover.png',
    );
  });

  test('url carries ?v=<hash> when the path is in the manifest', () {
    ContentMedia.debugSetVersions(
      const <String, String>{'eras/hong-bang/cover.png': 'abc1234567'},
    );
    expect(
      ContentMedia.url('eras/hong-bang/cover.png'),
      '$kContentMediaBase/eras/hong-bang/cover.png?v=abc1234567',
    );
  });

  test('a path with diacritics or spaces is percent-encoded', () {
    final url = ContentMedia.url('eras/đại-thắng/covér image.png');
    expect(url, isNot(contains(' ')));
    expect(url, isNot(contains('đ')));
    expect(url, startsWith(kContentMediaBase));
  });
}
