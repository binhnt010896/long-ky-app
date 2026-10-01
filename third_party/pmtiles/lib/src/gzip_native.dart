import 'dart:convert';
import 'dart:io';

/// LONG KY PATCH (see NOTICE-LONGKY.md): the gzip decoder on platforms with
/// `dart:io` — the fast native zlib, as upstream.
Converter<List<int>, List<int>> gzipDecoder() => zlib.decoder;
