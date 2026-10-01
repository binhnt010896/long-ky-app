# Patched copy of `vector_map_tiles` 8.0.0

This is `vector_map_tiles` 8.0.0 (BSD 3-Clause, Greensopinion — see `LICENSE`) with **three
small changes**, so the street screen's base map draws in a Flutter **web** build. Android and
iOS run the upstream code paths unchanged (every web change is behind `kIsWeb`).

The upstream layer fails on web for two reasons: it saves every tile to a disk cache
(`path_provider` + `dart:io` files — `MissingPluginException … getTemporaryDirectory`), and in
release builds it decodes tiles on a pool of isolates, which a browser cannot start.

1. `lib/src/cache/storage_cache.dart`: on web the disk cache keeps nothing — reads miss, writes,
   removals and clean-ups do nothing, and `path_provider` is never called. (The in-memory tile
   cache and the browser's HTTP cache still work.)
2. `lib/src/grid/grid_layer.dart`: on web the layer uses `QueueExecutor` (one in-page queue — what
   debug builds already use) instead of `newExecutor`'s isolate pool.
3. `lib/src/cache/vector_tile_loading_cache.dart` (all platforms): the first tile that fails to
   load is logged once with `debugPrint`; upstream drops the error silently. The error is
   re-thrown exactly as before.

Wired in by `dependency_overrides` in the workspace `pubspec.yaml`. Drop this directory and that
override once `vector_map_tiles` 9 is stable (it is in beta and needs `flutter_map` 8).
Patched lines are marked `LONGKY PATCH`.
