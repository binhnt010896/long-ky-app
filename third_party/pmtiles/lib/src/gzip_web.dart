import 'dart:convert';

import 'package:archive/archive.dart' show GZipDecoder;

/// LONG KY PATCH (see NOTICE-LONGKY.md): on Flutter web there is no
/// `dart:io` zlib (`Unsupported operation: _newZLibInflateFilter`), so gzip is
/// inflated by the pure-Dart `archive` package instead.
Converter<List<int>, List<int>> gzipDecoder() => _GzipDecoder();

class _GzipDecoder extends Converter<List<int>, List<int>> {
  @override
  List<int> convert(List<int> input) => GZipDecoder().decodeBytes(input);
}
