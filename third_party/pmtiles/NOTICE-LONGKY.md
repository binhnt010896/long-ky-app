# Patched copy of `pmtiles` 1.2.0

This is `pmtiles` 1.2.0 (BSD 2-Clause, Andrew Brampton — see `LICENSE`) with **three changes**,
both so the street screen's base map opens in a Flutter **web** build (Android and iOS were
never affected):

1. `lib/src/header.dart`: the 64-bit header fields are read as two 32-bit halves instead of
   `ByteData.getUint64`, which dart2js does not support.
2. `lib/src/archive.dart` + `gzip_native.dart` / `gzip_web.dart`: gzip is inflated by
   `dart:io` zlib as before, but by the pure-Dart `archive` package on web, where zlib does
   not exist (`Unsupported operation: _newZLibInflateFilter`).

3. `lib/src/archive.dart`: `PmTilesArchive.fromReadAt` loses its `@visibleForTesting`, so the
   app can put a read cache (`CachingReadAt`, in `street_basemap.dart`) in front of the HTTP reader.

It is wired in by `dependency_overrides` in the workspace `pubspec.yaml`. Delete this
directory and that override once upstream fixes it (https://github.com/brampton/pmtiles-dart).
