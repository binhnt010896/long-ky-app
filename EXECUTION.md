# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: PLANNING Cycle P (the street map: landmarks, a closer starting view,
the search box) plus the leftover web fix from Cycle O. Nothing in it is built.
It waits on the user's answers to P1–P4.**

Cycles M, N and O are built and pushed on branch `m-cycle`, kept separate from
`main` at the user's request. Their specs: `cfa220a:EXECUTION.md` (M),
`92e699f:EXECUTION.md` (N), `f56a4d7:EXECUTION.md` (O). The full diagnosis of
the web problem is in this file's previous version (git history).

## Audit of the previous plan

- **The base map draws on Android** — confirmed by the user on their phone, so
  Cycle O works where it matters: the real app. Step F-1 of the fix plan is
  done.
- **It still doesn't draw on web.** The cause is known, from the user's debug
  session and the `vector_map_tiles` 8.0.0 source: the map layer saves every
  tile to a disk cache (`path_provider`, `dart:io`), and in release builds it
  decodes tiles in Dart isolates. The browser has neither. The phone has both.
  The fix is **W-1** below, unchanged from the last plan's F-2 and F-3, and
  still waits on the user's answer (now **P1**).
- **The visual checklist (old O-4/O-5)** hasn't been run as a whole. It now
  runs once, at the end of this cycle (P-6), over the finished screen.

**Carried forward, in order (unchanged; all wait on the user's go):**
1. Merge `m-cycle` into `main`, then deploy the new CMS right away (the deployed
   CMS can't read the migrated content). The Worker's loader code only lives on
   `m-cycle` — redeploying the Worker from `main` before the merge would revert
   it to the old 50-request loader.
2. Publish: dry run → the user's yes → real publish. This publish also carries
   the street geometry and the base map through the pipeline. Until then the
   CDN only holds preview copies.
3. Firestore (still off): steps in `979cb3f:EXECUTION.md`, plus the updated
   `firestore.rules` (public read of `events/`).
4. A new app build for M, N, O and P.
5. From before: the Play closed test (last build `1.0.3+6`), Analytics custom
   definitions, the privacy page and Data safety form, Cycle E's items, and
   optionally deleting `admin-long-ky.web.app`.

## Cycle P — what the user asked for

> 1. For some people, it's hard to look at the map and see where they are,
>    because there's no landmark to anchor. Let's put some landmarks where they
>    belong: Bến Thành Market, Independence Palace, Tân Sơn Nhất Airport,
>    Notre-Dame Cathedral, the Turtle Lake, Landmark 81.
> 2. By default, let's zoom in a bit; currently it's too zoomed out.
> 3. The search box's placeholder "Tìm tên đường" sits close to the top of the
>    box; it should be vertically centred.

### What I checked (read-only, 2026-10-01)

- **Why the map opens so far out:** it starts with `CameraFit.insideBounds` over
  the whole camera lock. Old HCMC runs from Củ Chi (lat 11.16) down to Cần Giờ
  (10.14). That's more than 100 km, so the city centre, where nearly every
  gold street is, ends up a small knot in the middle.
- **Why the placeholder rides high:** the search `TextField` has
  `InputBorder.none`, `isDense: true` and a `prefixIcon`. The icon makes the
  field 48 px tall (Flutter's minimum tap size), but the text is top-aligned by
  default for a field with no outline. So both the hint and the typed text sit
  near the top.
- **What the base map already labels:** the Protomaps theme names districts,
  wards and roads. We hid its `pois` layer (it needs a sprite sheet, and it
  would compete with the gold). So none of the six landmarks shows today.
- The landmarks have no page in the app, and none needs one for this. They are
  for finding your way, not history entries.

### The steps

**P-1 — The landmark data.** It goes in `content/streets/hcm.json`, next to
the streets, so it travels with the mapping (bundled today, over the air when
the mapping does).
```json
"landmarks": [
  { "id": "cho-ben-thanh", "name": { "vi": "Chợ Bến Thành", "en": "Bến Thành Market" },
    "kind": "market", "lat": 10.7725, "lng": 106.6980, "osm": "way/…" }
]
```
- The six, in priority order (it decides whose label wins when two collide):
  Chợ Bến Thành (market), Dinh Độc Lập / Independence Palace (palace), Nhà thờ
  Đức Bà / Notre-Dame Cathedral (church), Hồ Con Rùa / Turtle Lake (lake),
  Landmark 81 (tower), Sân bay Tân Sơn Nhất / Tân Sơn Nhất Airport (airport).
- Coordinates come from OpenStreetMap, not from memory: each landmark's OSM
  object is looked up once, its centre point taken, and its id recorded in
  `osm` so a later check can find it again. (Approximate values for
  orientation: Bến Thành 10.7725, 106.6980 · Dinh Độc Lập 10.7770, 106.6953 ·
  Đức Bà 10.7798, 106.6990 · Hồ Con Rùa 10.7826, 106.6958 · Landmark 81
  10.7951, 106.7218 · Tân Sơn Nhất 10.8188, 106.6519.) For the airport, the
  point is the passenger terminal, not the middle of the runways.
- Model: `StreetLandmark` in `core_domain`'s street map, with
  `StreetMapFile.landmarks` (optional; empty is fine).
- The validator checks: ids unique, both names present, `kind` is one of the
  known kinds, and the point lies **inside the old-HCMC boundary**.
- `tool/street_map/suggest.dart` keeps `landmarks` when it rewrites `hcm.json`,
  the same way it keeps `basemap`, so a street refresh never wipes them.

**P-2 — Draw them.** A `MarkerLayer` above the base map and the outside mask,
**under** the gold streets' tap handling:
- Each landmark is a small round gold-outlined badge on lacquer, with a thin
  icon for its kind: market, palace, church, lake, tower, airport. The name
  goes under it in the app's caption type, in cream, with a soft dark halo so
  it reads over roads. The look is delicate, the same family as the street card
  — no pins or drop shadows of the Google kind.
- **Names follow the VI/EN toggle** (P3). We author both, so unlike the base
  map's OSM labels this costs nothing.
- **Labels never pile up:** the badges always show. A label is hidden when it
  would overlap one with higher priority (checked in screen space after each
  camera move). Bến Thành, Dinh Độc Lập, Đức Bà and Hồ Con Rùa are all within
  about 1 km of each other, so at the starting zoom some of their labels drop
  out until the reader zooms in.
- **Not tappable** (P4): the markers ignore taps, so tapping a gold street right
  next to a landmark still selects the street. Decision M2 ("the history
  streets are the only tappable thing") stands.
- Below zoom 11 the landmarks hide. At that scale they would just be a blob in
  the middle.

**P-3 — Open closer** (P2). Start centred on the city centre (around Bến
Thành) at **zoom 13**, instead of fitting the whole of old HCMC:
- At zoom 13 a phone shows roughly District 1, District 3 and the edges of
  Bình Thạnh and District 4, which is where most gold streets and five of the
  six landmarks are.
- The starting centre is a field in `hcm.json` (`"start": {"lat", "lng",
  "zoom"}`), so other cities later bring their own. The validator checks the
  centre is inside the boundary and the zoom is within the camera's 10–17.
- Unchanged: zooming out to 10, the camera lock (the sovereignty guard), and
  `?street=<id>` opening fitted to that street.

**P-4 — Centre the search text.** Give the field
`textAlignVertical: TextAlignVertical.center`, with a symmetric
`contentPadding`, so the hint and the typed text both sit on the field's
middle line. The prefix icon keeps its size.

**P-5 — Tests.**
- `core_domain`: parsing `landmarks` and `start`; each validator rule (a
  landmark outside the boundary, a duplicate id, a missing name, an unknown
  kind, a start outside the boundary or out of zoom range); `hcm.json` passes.
- Mobile widget tests: the six landmark badges render; labels follow VI/EN; a
  tap on a street next to a landmark still selects the street; the map opens
  at the configured centre and zoom; with `?street=` it still fits the street.
  The search hint's vertical centre is within 1 px of the field's centre.
- The usual sweep: format, `validate_content`, core_domain, mobile, admin,
  `melos analyze`.

**P-6 — See it**, on the phone (release APK) and, if P1 is "patch", in a
release web build at `http://localhost:3000`. Screenshots go to the user:
- The opening view: the city centre, gold streets on the base map, the
  landmarks readable, no labels on top of each other.
- Zooming 11 → 15: labels appear as space allows. At 10 the landmarks hide.
- The search box text is centred, in both VI and EN.
- **Sovereignty guard holds:** the camera can't leave the old-HCMC box or go
  below zoom 10. No sea or ocean labels, no national borders. Vietnamese base
  map labels. The credit "© OpenStreetMap contributors · Protomaps" is
  visible.
- Panning makes small range requests (tens of KB), never the 37 MB file.

**P-7 — Commit on `m-cycle`** and update this file with what was seen.

**W-1 — The web fix** (only if P1 = patch). Vendor `vector_map_tiles` 8.0.0
into `third_party/vector_map_tiles`, the same way as `third_party/pmtiles`: an
unmodified copy, plus a small patch, plus `NOTICE-LONGKY.md` listing every
changed line. Wire it in with `dependency_overrides` in the root
`pubspec.yaml`. Every change is web-only, so phones run the upstream code
unchanged:
- **The cache:** on web, the disk cache keeps nothing — reads say "not
  cached", saves and clean-ups do nothing — and `path_provider` is never
  called. The layer's in-memory cache and the browser's HTTP cache still work.
- **The workers:** on web, tiles are decoded on the single in-page queue
  (`QueueExecutor`) in every build mode, in the vector path and in the raster
  path.
- Plus: the first tile failure is logged once with `debugPrint`, so a broken
  base map is no longer silent. The plain ground stays the fallback.
- A unit test for the web cache stub, and both release builds (web and APK)
  still build.
- **Drop both vendored copies** once `vector_map_tiles` 9 ships stable (it's
  in beta now and needs `flutter_map` 8).

### Scope notes

- **Not in P:** more landmarks, an in-house lacquer base-map style, tapping a
  landmark, "streets near me", and other cities. All queued below.
- These landmarks are places to find your way, not content: no page, no
  sources, no art. If one later gets a history entry (Dinh Độc Lập and 30/4/1975
  is the obvious one), linking it is a separate decision.

## Decisions for the user

- **P1 — Base map on web.** Recommend **patching it (W-1)**: you check
  changes in web builds every day, so a working web base map makes every future
  street-map change checkable there, P-6 included. Cost: a second vendored
  package, about 30 changed lines, all behind web-only switches, dropped once
  `vector_map_tiles` 9 is stable. Alternative: **no base map on web** — the
  screen skips the layer on web (a few lines), and the base map is only
  checkable on a phone.
- **P2 — The opening view.** Recommend **centred on Bến Thành at zoom 13**,
  stored in `hcm.json`. It shows the city centre, where most gold streets and
  five of the six landmarks are, with room to zoom either way. Alternatives:
  zoom 12 (a wider view, takes in Tân Sơn Nhất too, but the centre's labels get
  crowded) or zoom 14 (very close, mostly District 1).
- **P3 — Landmark names.** Recommend **following the VI/EN toggle**: we write
  both names ourselves, so it's free, and an English reader gets "Independence
  Palace" rather than only "Dinh Độc Lập". The base map's own labels stay in
  Vietnamese (O4). Alternative: always Vietnamese, matching the base map.
- **P4 — Tapping a landmark.** Recommend **not tappable for now**: the
  landmarks are for finding your way, and M2 keeps the gold streets as the only
  tappable thing. Alternative: a tap opens a small card with the name and,
  where one exists, a link into the chronicle. That would need its own content
  decisions (which event, which era) first.

## Next cycles (queued)

- **More landmarks** (e.g. Nhà hát Thành phố, Bưu điện Thành phố, Bến Nhà
  Rồng, Chợ Lớn/Chợ Bình Tây, Thảo Cầm Viên) — a data-only change once P is in.
- **An in-house lacquer style for the base map** (O3 kept the stock theme).
- **Write the first standalone events** in the CMS — the machinery is done; no
  real standalone event exists yet.
- **Streets near me** (deferred from M): "while using the app" location
  permission, on-device only, a Play Data safety update, a "Gần tôi" button.
- **More cities:** Hà Nội first, then Huế and Đà Nẵng.
- **A CMS editor for street mappings** (and, after P, landmarks).
- **Content cycle for famous streets with no page yet:** Nguyễn Hữu Cảnh first,
  then Lê Hồng Phong, Võ Thị Sáu, Phan Văn Trị, Nguyễn An Ninh, Hoàng Văn Thụ,
  Trần Văn Giàu.
- **Street mapping over the air** (it ships bundled today) and the **media
  manifest live via Firestore** (deferred from K5).
- **Carried-over UX audit findings:** particles over text, Chào cờ lyrics
  legibility, swipe-hint timing — see `21fb88b:EXECUTION.md`.
