/// Small typed accessors for hand-parsing content JSON with useful errors.
///
/// The content contract is enforced ahead of runtime by `tool/validate_content`
/// against `era.schema.json`; these helpers give the loader a second, in-code
/// guard and turn a malformed field into a precise [ContentFormatException]
/// instead of a raw cast error.
library;

/// Thrown when a content document does not match the expected shape.
class ContentFormatException implements Exception {
  ContentFormatException(this.message, {this.path});

  final String message;

  /// Dotted path to the offending field, e.g. `events[0].year.display`.
  final String? path;

  @override
  String toString() => path == null
      ? 'ContentFormatException: $message'
      : 'ContentFormatException at `$path`: $message';
}

extension JsonMap on Map<String, dynamic> {
  /// A required nested object.
  Map<String, dynamic> obj(String key, {String? at}) {
    final v = this[key];
    if (v is Map<String, dynamic>) return v;
    throw ContentFormatException(
      v == null ? 'missing required object `$key`' : '`$key` is not an object',
      path: _join(at, key),
    );
  }

  /// An optional nested object.
  Map<String, dynamic>? objOrNull(String key, {String? at}) {
    final v = this[key];
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    throw ContentFormatException('`$key` is not an object', path: _join(at, key));
  }

  /// A required string.
  String str(String key, {String? at}) {
    final v = this[key];
    if (v is String && v.isNotEmpty) return v;
    throw ContentFormatException(
      v == null ? 'missing required string `$key`' : '`$key` is not a string',
      path: _join(at, key),
    );
  }

  /// An optional string.
  String? strOrNull(String key, {String? at}) {
    final v = this[key];
    if (v == null) return null;
    if (v is String) return v;
    throw ContentFormatException('`$key` is not a string', path: _join(at, key));
  }

  /// A required integer.
  int integer(String key, {String? at}) {
    final v = this[key];
    if (v is int) return v;
    throw ContentFormatException(
      v == null ? 'missing required int `$key`' : '`$key` is not an int',
      path: _join(at, key),
    );
  }

  /// An optional integer (accepts explicit null).
  int? integerOrNull(String key, {String? at}) {
    final v = this[key];
    if (v == null) return null;
    if (v is int) return v;
    throw ContentFormatException('`$key` is not an int', path: _join(at, key));
  }

  /// An optional boolean with a default.
  bool boolOr(String key, bool fallback, {String? at}) {
    final v = this[key];
    if (v == null) return fallback;
    if (v is bool) return v;
    throw ContentFormatException('`$key` is not a bool', path: _join(at, key));
  }

  /// An optional list of strings (empty when absent).
  List<String> stringList(String key, {String? at}) {
    final v = this[key];
    if (v == null) return const <String>[];
    if (v is! List) {
      throw ContentFormatException('`$key` is not a list', path: _join(at, key));
    }
    return <String>[
      for (final e in v)
        if (e is String)
          e
        else
          throw ContentFormatException('element is not a string',
              path: _join(at, key)),
    ];
  }

  /// A required list of objects, mapped through [fromJson].
  List<T> list<T>(
    String key,
    T Function(Map<String, dynamic> json, String at) fromJson, {
    String? at,
  }) {
    final v = this[key];
    if (v is! List) {
      throw ContentFormatException(
        v == null ? 'missing required list `$key`' : '`$key` is not a list',
        path: _join(at, key),
      );
    }
    final base = _join(at, key);
    return <T>[
      for (var i = 0; i < v.length; i++)
        if (v[i] is Map<String, dynamic>)
          fromJson(v[i] as Map<String, dynamic>, '$base[$i]')
        else
          throw ContentFormatException('element is not an object',
              path: '$base[$i]'),
    ];
  }
}

String _join(String? at, String key) => at == null ? key : '$at.$key';
