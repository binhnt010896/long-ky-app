/// A 32-bit FNV-1a hash of [s]. Unlike `String.hashCode` it is the same on
/// every run and platform, so a choice made from it (which art starts hidden,
/// which question a page asks) is the same for every reader.
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}
