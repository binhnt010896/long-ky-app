# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: Cycle O (a base map under the street map) is partly built: the file
is made, uploaded and wired through the pipeline, but the map still does not
draw — see "Where O stands". O1–O4 were all confirmed as recommended.**

Cycles M and N are built and pushed on branch `m-cycle`, kept separate from
`main` at the user's request. Their specs: `cfa220a:EXECUTION.md` (M) and
`92e699f:EXECUTION.md` (N); what shipped in N: `9ddc32a:EXECUTION.md`.

## Audit of the previous plan

Done since the last plan:
- **The CMS loads through the new Worker loader** — confirmed by the user.
- **The street geometry exists.** `hcm-streets.geojson` was regenerated from
  fresh OSM data on this Mac (the approved mapping came out unchanged: 92
  streets, all approved), validated against the mapping, and uploaded to
  `long-ky-sources`. A CI dry run of `m-cycle` then passed end to end
  (`1 added · 0 missing`, run `36807478902`).
- **A preview copy is on the CDN** at `media/streets/hcm-streets.geojson`
  (5-minute cache), so the street map can be tried in a dev build before any
  publish. The user's dev build now draws the gold streets.
- The street tools now inline `{ref}` events before matching (`fdf365f`).

**Carried forward, in order (unchanged; all wait on the user's go):**
1. Merge `m-cycle` into `main`, then deploy the new CMS right away (the deployed
   CMS can't read the migrated content). The Worker's loader code only lives on
   `m-cycle` — redeploying the Worker from `main` before the merge would revert
   it to the old 50-request loader.
2. Publish: dry run → the user's yes → real publish.
3. Firestore (still off): steps in `979cb3f:EXECUTION.md`, plus the updated
   `firestore.rules` (public read of `events/`).
4. A new app build for M, N and O.
5. From before: the Play closed test (last build `1.0.3+6`), Analytics custom
   definitions, the privacy page and Data safety form, Cycle E's items, and
   optionally deleting `admin-long-ky.web.app`.

## Where O stands (2026-10-01)

**Done and verified**
- **O-1:** `hcm-basemap.pmtiles` extracted from Protomaps build `20261001`:
  **37 MB**, zoom 10–15 only, bounds exactly old HCMC plus the camera margin
  (`pmtiles show`). Nothing below zoom 10 exists, so the open sea and the island
  chains cannot appear.
- **O-2:** `hcm.json` has `"basemap": "streets/hcm-basemap.pmtiles"`;
  `StreetMapFile.basemap`, the validator rule (`.pmtiles` only), `.pmtiles` in
  all three media tools, `.gitignore`, and the app resolving the address through
  the media manifest (a dart-define still overrides). Tests added (core_domain
  95, mobile 191, analysis clean).
- **O-3:** uploaded to `long-ky-sources` and, as a preview, to the CDN at
  `media/streets/hcm-basemap.pmtiles` (5-minute cache); both hashes match.
  A browser range request returns `206` with CORS.
- The credit line reads "© OpenStreetMap contributors · Protomaps".
- **The file and the library are good:** the app's own `pmtiles` library opens
  the CDN file and returns real tiles (94–142 KB) at zoom 10, 12 and 14.
- Also fixed on the way: `write_media_ledger.dart` did not know `.geojson`, so
  the ledger would have forgotten the street geometry after every publish.

**Found and fixed for Flutter web** (`third_party/pmtiles`, a patched copy wired
in by `dependency_overrides`; see its `NOTICE-LONGKY.md`): upstream `pmtiles`
reads 64-bit header fields with `getUint64` (dart2js can't) and gunzips with
`dart:io` zlib (not on web). Both patched; Android and iOS never needed it.

**NOT working: the map does not draw.** In a web build the file's header is read
(180 ms) and then the tile layer never requests a single tile, with no error.
I also cached the theme and the tile-provider map (they were rebuilt every
frame, which restarts the vector layer) — no change on web. **Not yet known
whether this is web-only:** the phone was disconnected when I got to it
(`adb: no devices`), so Android is untested. The base map has therefore not been
seen on any screen, and O-4 and O-5 are not done.

### What to do next
1. **Reconnect the phone** and run the release APK (already built) to see
   whether Android draws the map. Everything after depends on this answer:
   - **Draws on Android:** the base map is shippable for the app (the real
     product); web stays a dev preview without it, or gets one more fix.
   - **Doesn't draw on Android either:** the problem is in how the vector layer
     is used (not the file or web). Next suspects: the layer waiting on assets
     the Protomaps theme needs, or its zoom/camera interplay with the camera
     constraint. If that stays stubborn, the fallback is rendering the same file
     with a different Flutter map layer.
2. Then O-4 (the visual and sovereignty checklist, with screenshots) and O-5.
3. Commit on `m-cycle` (done for the work above; nothing is on `main`).

## Cycle O — what the user asked for

> Shouldn't we have a background map overlay? Looking at this, I don't know
> where is where.

Right now the street map shows gold lines on a plain dark ground — no river, no
districts, no labels. The screen already supports a base map (Cycle M's M-B);
what's missing is the map file itself, so `STREET_BASEMAP_URL` is empty and the
screen falls back to the plain ground on purpose.

### What I checked (read-only, 2026-10-01)

- **The CDN serves partial requests.** A `Range: bytes=0-99` request to
  `r2.dev` returns `206 Partial Content` with `Accept-Ranges: bytes`, and keeps
  the CORS header for a browser origin. That was decision M1's open risk; the
  hosted-provider fallback is not needed.
- **Protomaps publishes a fresh world build daily**: `20261001.pmtiles`,
  138.5 GB, format v4.15.2 — the v4 the app's theme
  (`vector_map_tiles_pmtiles`, `themes/v4`) expects. We never download the
  whole thing: the extract tool reads only the parts inside our box.
- **The app side exists**: `street_basemap.dart` builds the Protomaps dark theme
  minus `water_label_ocean`, `boundaries_country` and `pois`; the camera is
  locked to the old-HCMC bounds plus a margin, minimum zoom 10.

### The steps

**O-1 — Make the extract.**
- Install the `pmtiles` command-line tool (`go install` from
  `github.com/protomaps/go-pmtiles`; Go is already on this Mac).
- Cut old HCMC out of the latest build:
  `pmtiles extract https://build.protomaps.com/<date>.pmtiles
  build/basemap/hcm-basemap.pmtiles --bbox=<boundary + margin> --minzoom=10
  --maxzoom=15` (O2). The box comes from `content/streets/hcm-boundary.geojson`
  plus the same margin the camera lock uses, so the map never shows an edge.
- Check it with `pmtiles show`: its bounds, its zoom range (nothing below 10),
  and its size (expected: tens of MB — measured here, reported before anything
  is uploaded).

**O-2 — Ship it the way the street geometry ships (O1).**
- `content/streets/hcm.json` gains `"basemap": "streets/hcm-basemap.pmtiles"`,
  next to its `"geometry"`. The app reads the served URL from the media manifest,
  exactly like the geometry — versioned (`?v=…`), cached, and replaceable by a
  publish, **no app update needed** to refresh the map.
- `gen_media_manifest`, `media_ledger` and `write_media_ledger` learn
  `.pmtiles` (copied as-is, never converted).
- `STREET_BASEMAP_URL` stays as a dev override (a build-time setting wins over
  the manifest), so a local test can point anywhere.
- The validator checks a street map's `basemap` path is a `.pmtiles` media path.
- Tests: the street-data parser reads `basemap`; the URL resolves through the
  manifest; with no basemap the screen still shows the plain ground (today's
  behaviour, kept as the fallback).

**O-3 — Upload** (needs the user's yes).
- The original goes to `long-ky-sources` (`tool/push_sources.sh`, add-only).
- For a preview before the merge, the same file is copied to the CDN path the
  app asks for — as was done for the geometry — with a short cache.

**O-4 — Check it in a browser** (the dev build the user already runs).
- Rivers, roads and district/ward names appear under the gold streets; the gold
  stays clearly on top (O3).
- **Sovereignty guard holds:** the camera can't leave the old-HCMC box or zoom
  out past 10; no sea or ocean labels; no national borders. With nothing below
  zoom 10 in the file, the low-zoom tiles that cover the open sea and the island
  chains don't exist to be shown at all.
- Labels are in Vietnamese (O4).
- Attribution reads "© OpenStreetMap contributors · Protomaps" and stays
  visible (ODbL).
- Network: panning loads only small range requests (tens of KB), not the file.
- Screenshots at a few zoom levels, sent to the user.

**O-5 — Check it on a phone.** A release build on the user's Android phone:
smooth panning and zooming, and the first map paint within a few seconds on a
normal connection.

**O-6 — Commit on `m-cycle`** (the user keeps it separate from `main`) and
update this file. The base map reaches readers with the next merge, publish and
app build — the same path as the rest of M and N.

### Scope notes

- **Not in O:** an in-house lacquer map style (queued); other cities; "streets
  near me".
- **Refreshing the map later** is the same three commands (extract → upload →
  publish); OSM changes slowly, so once or twice a year is plenty.
- **Licensing:** Protomaps' basemap is built from OpenStreetMap (ODbL). The
  in-app credit and the About page note from Cycle M already cover it.

## Decisions for the user

- **O1 — Where the app gets the map's address.** Recommend **through the media
  manifest** (a `basemap` field in `hcm.json`, like the street geometry): one
  pipeline, versioned, and a refreshed map ships with a publish, not an app
  update. Alternative: bake the URL into the app build — simpler, but every map
  refresh needs a new app version.
- **O2 — Zoom range.** Recommend **zoom 10–15**: it matches the camera's limits,
  keeps the file small, and means the low-zoom tiles that would include the open
  sea and the island chains are never in the file at all. Alternative: 0–15, a
  bigger file with nothing the camera can show.
- **O3 — Style.** Recommend **Protomaps' stock dark theme for now** (minus the
  layers already hidden), checked by eye that the gold streets read clearly on
  top; an in-house lacquer style is its own later cycle. Alternative: design the
  in-house style now — a few more days, and a visual review loop.
- **O4 — Label language.** Recommend **Vietnamese labels** (OSM's `name`, which
  in Vietnam is Vietnamese), with English place names only where OSM has no
  Vietnamese one. Alternative: follow the app's VI/EN toggle — more work, and
  most HCMC places have no separate English name anyway.

## Next cycles (queued)

- **An in-house lacquer style for the base map** (if O3 keeps the stock theme).
- **Write the first standalone events** in the CMS — the machinery is done; no
  real standalone event exists yet.
- **Streets near me** (deferred from M): "while using the app" location
  permission, on-device only, a Play Data safety update, a "Gần tôi" button.
- **More cities:** Hà Nội first, then Huế and Đà Nẵng.
- **A CMS editor for street mappings.**
- **Content cycle for famous streets with no page yet:** Nguyễn Hữu Cảnh first,
  then Lê Hồng Phong, Võ Thị Sáu, Phan Văn Trị, Nguyễn An Ninh, Hoàng Văn Thụ,
  Trần Văn Giàu.
- **Street mapping over the air** (it ships bundled today) and the **media
  manifest live via Firestore** (deferred from K5).
- **Carried-over UX audit findings:** particles over text, Chào cờ lyrics
  legibility, swipe-hint timing — see `21fb88b:EXECUTION.md`.
