/// Prefixes OSM street names carry that carry no identity ("Đường Lê Lợi",
/// "Phố Huế"). Compared after case folding, longest first.
const _prefixes = <String>[
  'đại lộ',
  'đường',
  'phố',
  'quốc lộ',
  'hẻm',
];

/// Honorifics that appear in our people names but never on a street sign
/// ("Đại tướng Võ Nguyên Giáp" → the street is "Võ Nguyên Giáp").
const _titles = <String>[
  'đại tướng',
  'thượng tướng',
  'trung tướng',
  'chủ tịch',
  'thái sư',
  'quốc công',
  'hưng đạo đại vương',
  'thái úy',
  'đại vương',
  'thánh',
  'vua',
  'hoàng đế',
  'đức thánh',
];

/// Folds a street (or person/era/event) name to the key used for matching:
/// lower-cased, whitespace collapsed, punctuation-light, and — for street
/// names — without a leading "Đường / Phố / Đại lộ".
///
/// Diacritics are deliberately kept: Vietnamese names differ by them
/// ("Lý Thường Kiệt" vs "Lý Thường Kiết"), and OSM names are NFC.
String normalizeName(String raw, {bool stripStreetPrefix = false}) {
  var s = raw
      .toLowerCase()
      .replaceAll(RegExp(r'[–—\-–—]'), ' ')
      .replaceAll(RegExp(r'[.,;:()"“”]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (stripStreetPrefix) {
    for (final p in _prefixes) {
      if (s.startsWith('$p ')) {
        s = s.substring(p.length + 1).trim();
        break;
      }
    }
  }
  return s;
}

/// The street-sign spellings a person's display name can take: split on "·"
/// ("Nguyễn Huệ · Quang Trung" → both), then drop a leading [_titles] entry.
List<String> personNameVariants(String displayName) {
  final out = <String>{};
  for (final part in displayName.split('·')) {
    var n = normalizeName(part);
    for (final t in _titles) {
      if (n.startsWith('$t ')) {
        n = n.substring(t.length + 1).trim();
        break;
      }
    }
    if (n.isNotEmpty) out.add(n);
  }
  return out.toList();
}
