# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: PLANNING COMPLETE — Cycle M (a map of Ho Chi Minh City's
history-named streets). M1–M5 are confirmed as recommended (below). Nothing
is built yet; the next step is an EXECUTION session.**

## Cycle M — execution status (branch `m-cycle`)

**Built and tested (no network needed):**
- **M-A code:** `core_domain/src/street_map/` (name normalization, matcher with
  home-era resolution, never-unapprove merge, Douglas–Peucker + segment
  chaining, hit-testing, `StreetMapValidator`), with 20 tests.
  `tool/street_map/{fetch_boundary,suggest,build_geometry}.dart`,
  `content/streets/aliases.json` (9 curated aliases, real ids),
  `validate_content` runs the street rules, and the media ledger/manifest
  carry `.geojson`.
- **M-B (partial):** the Protomaps dark v4 theme minus `water_label_ocean`,
  `boundaries_country` and `pois` (sovereignty guard, unit-tested); camera
  locked with `CameraConstraint.contain` + min zoom 10.
- **M-C:** `/duong-pho` screen (gold streets, outside-mask, tap → card,
  search, `?street=`, attribution, `street_tap`/`street_open_detail`).
- **M-D:** Sảnh entry, reverse chip on Character and Event pages, About-page
  OSM/Protomaps/ODbL note.
- **Checked:** 169 app tests + 58 core_domain tests pass, analyzer clean, web
  build compiles, and a real-browser run against a throw-away fixture showed
  the streets, the tap → card and the attribution.

**Street data (done):** `hcm-boundary.geojson` (old HCMC, 10.14–11.16 N,
106.36–107.03 E) and `hcm.json` are committed: **92 streets, all approved**
(74 exact matches + 18 reviewed alias/multi-target rows, approved by the user
on 2026-09-30). `hcm-streets.geojson` (92 streets, 659 lines, 3,145 points,
75 KB) is generated and git-ignored; `validate_content` checks it.
Fixes found while running it: OSM spells some names with the look-alike
**Ð (U+00D0)** — Đồng Khởi was invisible because of it — so names are now
folded to Đ and NFC-normalized; the download is tiled, cached and resumable
(`build/streets/tiles/`, use `suggest.dart --offline` to re-match without
network); geometry is written to `content/streets/` (where the media pipeline
reads it).

**Still to do (yours):**
1. `tool/push_sources.sh` to put `content/streets/hcm-streets.geojson` in
   `long-ky-sources`, then the normal publish (dry run → yes → real).
2. **The PMTiles extract** (bbox from the boundary + 0.05° margin, z ≤ 15),
   its R2 upload, and the r2.dev `Range` check. `STREET_BASEMAP_URL` is empty
   until then, so the map shows the lacquer ground and gold streets only. The
   basemap has not been visually verified.
3. A new app build (the screen and its packages are app code).

**Deviations:** the basemap uses Protomaps' stock dark theme (not in-house
styled); the street mapping ships bundled (`assets/content/streets/`), not OTA,
because the content pack and Firestore sync only carry eras/people/periods.

## Cycle N — planned: events separate from eras (decisions confirmed)

> An event not yet in any era can simply be a standalone event. Make events
> independent of era and period.

**Decided:**
- **At most one era per event.** An event is in one era or none.
- **A standalone event needs only its own citation** (no era `primarySource`).
- **Order:** Cycle M finishes first; this is Cycle N.

**Design (recommended B — the people pattern):**
- `content/events.json` is the registry of every event (+ schema). Eras list
  `events: [{ref}]` in reading order; an event no era lists is standalone.
  Event `order` stops being era-relative (the era's list order is the order).
- A migration script moves all events out of the 38 era files, text unchanged,
  verified by rebuilding and diffing the inlined eras.
- **Compatibility:** the content pack and Firestore keep inlining events into
  each era, so installed apps parse them as today; the app also learns refs for
  the bundled files. Whether any installed build reads the OTA pack still has
  to be confirmed — treat compatibility as required until it is.
- **Validation:** event ids unique; every ref resolves; an event in two eras is
  an error; every event has a citation; relatedEventIds may cross eras.
- **App:** standalone route `/su-kien/:id` (neutral lacquer look); standalone
  events join the global timeline by year and the quiz; street targets for
  events no longer need an era.
- **CMS:** an Events screen (create/edit/assign to an era); the era editor
  picks from it and orders them.
- **Open in N:** default palette/backdrop for standalone events; how a
  standalone event's year places it on the timeline; whether the era
  `minItems: 1` on events relaxes.

## Audit of the previous plan

**Cycle L is fully shipped:**
- **Download original** in the CMS media dialog (`30b5e7b`). It fetches the
  untouched file from `long-ky-sources`. The size label now says "served
  WebP", and I fixed a layout overflow the dialog already had.
- **Eras 36/37 art swapped.** All four originals were backed up to
  `_replaced/2026-09-28T14-31-03Z/` first. The swap is published and I
  checked it on the live CDN.
- **"2020 – now" → "2020 – nay"** (`4b672ed`), published.
- **The CMS is deployed** to long-ky-admin.web.app, so the events editor
  (K7) is live now.

**Two pipeline bugs came up while publishing, and both are fixed:**
- `4f27b82`: the incremental content-pack check needed every original on
  disk. Dry runs never caught it because they skipped that step; they now
  build the pack too.
- `6b8fba8`: a text-only publish (nothing to convert) demanded cwebp anyway.

The last real publish was `3d717ea` (pack `20260929070006`), and it was green.

**Still open, in the user's hands** (unchanged, carried forward):
1. **Turn Firestore on.** Until then the app keeps using the R2 pack. Full
   steps are in `979cb3f:EXECUTION.md`:
   - enable Firestore;
   - paste in `firestore.rules`;
   - add the `FIREBASE_SERVICE_ACCOUNT_KEY` GitHub secret;
   - run the one-time bootstrap.
2. **Build and upload a new app version.** 1.0.2+4 was never uploaded, so
   Cycles J, K and M all ride on the next build.
3. **Play closed test:** 12+ testers opted in for 14 days straight.
4. **Firebase → Analytics → Custom definitions:** `era_slug`, `event_id`,
   `figure_id`.
5. **Privacy page:** deploy it, and make Play's Data safety form match it.
6. **From Cycle E:** the `long_ky_tea*` products, license testing, a test
   purchase, screenshots, and the feature graphic.
7. **Optional:** delete the unused Hosting site `admin-long-ky.web.app`.

## Cycle M — what the user asked for

> A map of HCMC (other cities later), built on OpenStreetMap. Tap a street to
> see its name and who or what it's named after (a hero or an event), with a
> button that goes straight to that Character or Event detail page.

**Decided already:**
- **Area:** only the **old (pre-July-2025) HCMC territory**. That excludes
  what was Bình Dương and Bà Rịa–Vũng Tàu.
- **"Streets near me":** a good idea, but it **comes later**. It needs
  location permission and a Data safety update. It's listed under "Queued"
  below and is not in this cycle.

### What I measured (real OSM data, 2026-09-29)

- **Size of the area:** inside the old HCMC boundary there are **34,185 named
  road segments** and **15,435 distinct street names**.
- **Exact matches:** **82 street names** match a figure or era we already have
  a page for, with no aliasing needed. That covers about **2,450 segments /
  17k points**, or about **360 KB of GeoJSON raw (~100 KB gzipped)**. Only
  these get drawn, so the map layer stays small.
- **Why events matched zero:** our event titles are written as events, not
  street names ("Chiến thắng Điện Biên Phủ", "Cách mạng Tháng Tám và Tuyên
  ngôn Độc lập", "Phong trào Đồng khởi", "Cao trào Xô viết Nghệ – Tĩnh").
  Streets named Điện Biên Phủ, Cách Mạng Tháng Tám, Đồng Khởi, Xô Viết Nghệ
  Tĩnh, Bạch Đằng, Nam Kỳ Khởi Nghĩa and Hồng Bàng need a short curated alias
  list. Figure names need the same: "Quang Trung" ↔ "Nguyễn Huệ · Quang
  Trung", "Nguyễn Tất Thành" ↔ "Chủ tịch Hồ Chí Minh". With aliases I expect
  **about 100 streets**.
- **One street, several targets:**
  - "Bạch Đằng" is three battles (Ngô Quyền, Lê Hoàn, Trần Hưng Đạo).
  - "Trần Hưng Đạo", "Lê Lợi", "Ngô Quyền" and others are a person **and** an
    era.
  - "Hai Bà Trưng" is two people.
- **People have no home era.** `people.json` has none, but the figure route
  is `/era/:slug/figure/:id`, so each person needs one.
- **The busiest streets with no page yet** (a content backlog, not this
  cycle): Nguyễn Hữu Cảnh (founded Saigon, 1698), Lê Hồng Phong, Võ Thị Sáu,
  Phan Văn Trị, Nguyễn An Ninh, Hoàng Văn Thụ, Trần Văn Giàu. HCMC also has
  **Hoàng Sa** and **Trường Sa** streets.

### M-A — street data (a tool plus a content file)

1. **Old boundary.** `tool/street_map/fetch_boundary.dart` asks Overpass for
   HCMC's admin relation **as it was on 2025-06-01** (an "attic" query). It
   writes `content/streets/hcm-boundary.geojson`, which is committed and
   small. The fallback is geoBoundaries' pre-2025 polygon, but that one is
   coarse (115 points) near the Dĩ An/Thuận An edge.
2. **Suggest matches.** `tool/street_map/suggest.dart`:
   - fetches the named `highway=*` ways inside the boundary and normalizes
     their names (drops "Đường / Phố / Đại lộ", folds case);
   - matches them against people names (splitting on "·", dropping titles
     like "Đại tướng", "Chủ tịch"), era titles, event titles, and
     `content/streets/aliases.json` (curated by hand);
   - writes or merges `content/streets/hcm.json`:
     `{schemaVersion, city, osmSnapshot, streets: [{id, name, targets:
     [{type: person|event|era, id, era}], status: suggested|approved}]}`.
   - **Only `approved` streets ship.** A re-run never un-approves anything or
     overwrites a hand edit.
3. **Geometry.** `tool/street_map/build_geometry.dart`:
   - takes the approved streets' segments;
   - merges them per street and simplifies them (Douglas–Peucker, about 5 m);
   - rounds coordinates to 5 decimals;
   - writes `streets/hcm-streets.geojson`.

   This is **generated, not hand-edited**. It's stored in `long-ky-sources`
   like any media original and reaches phones through the existing media
   pipeline. `gen_media_manifest.dart` learns `.geojson` (copied as-is, not
   converted). K1–K4's incremental publish then ships it only when it
   changes.
4. **Validator rules** (`content_validation`, with tests):
   - every target resolves (the person exists, the era slug exists, the
     event id exists in that era);
   - street ids are unique;
   - every approved street is present in the geometry.
5. **Home era for figures.** Default: the earliest era (by `order`) whose
   roster lists the person. A target can override it with `era`.

### M-B — the basemap

- **Recommended (M1):** a **Protomaps PMTiles extract** of the old HCMC bbox
  (z ≤ 15), hosted on `long-ky-content` R2. The app reads it with
  `flutter_map` + `vector_map_tiles` (+ its PMTiles provider), fetching only
  the tiles on screen through HTTP range requests.
  - Styled in-house to match the lacquer look: a dark ground and muted roads,
    so the gold history streets stand out.
  - Labels use `name:vi`/`name`.
  - Size gets measured during execution; I expect tens of MB on R2, and a
    phone only downloads what it views.
  - Execution checks early that r2.dev serves `Range` correctly. If it
    doesn't, fall back to MapTiler's free tier.
- **Sovereignty guard (hard requirement):**
  - the camera is locked to the old-HCMC boundary plus a small margin, with a
    minimum zoom of about 10, so the open sea and the island chains never
    come into view;
  - the style hides sea and ocean labels.
- **Attribution (ODbL):**
  - "© OpenStreetMap contributors" is always visible on the map, and the
    About page lists OSM + Protomaps.
  - The derived street GeoJSON is an ODbL database. It stays openly available
    (it's on a public bucket anyway), and the About page says so.

### M-C — the street map screen

- **Route and title:** `/duong-pho`, titled **"Đường phố mang tên sử"** /
  "Streets named for history". It follows the EN toggle.
- **What's drawn:** the basemap, a soft mask outside the old boundary, and
  the approved streets as **gold polylines**. Nothing else can be tapped
  (M2).
- **Tap a street:**
  - Hit-testing uses a pure function (nearest polyline within about 24 dp),
    so thin streets are easy to hit. It's unit-tested.
  - A small card opens with the street name, then one row per target:
    - person: name, epithet, and a line of the bio → **Xem nhân vật**;
    - event: title and year → **Xem sự kiện**;
    - era: title and year range → **Xem thời kỳ**.
  - Streets with several targets list every row.
  - Each button deep-links to the existing
    `/era/:slug/figure/:id`, `/era/:slug/event/:id` or `/era/:slug`.
- **Search:** a light "Tìm tên đường" field over the approved streets that
  flies the camera to the one you pick. The list is only about 100 names, so
  it's cheap.
- **Arriving from a detail page:** `?street=<id>` opens the map already
  zoomed to that street with its card showing.
- **Analytics:** `street_tap` and `street_open_detail`, both carrying
  `street_id` and `target`.

### M-D — entry points (M4)

- **Sảnh:** a new entry, "Đường phố mang tên sử". There is **no Home pill**,
  per the delicate-UI rule.
- **Reverse chip** on Character and Event detail pages, shown only when that
  page is a target of an approved street: "Một con đường ở TP.HCM mang tên
  này → Xem trên bản đồ".

### Scope notes

- **What ships over the air:** the mapping and geometry are content, so they
  ship OTA like the rest. The screen and the new map packages are app code,
  so they need the **next app build** (the same build as J/K).
- **Modern leaders' streets** (Võ Văn Kiệt, Đỗ Mười, …) use the existing
  short, dated, record-only bios. No new political text is written for this
  feature (history-not-politics).
- **Tests:**
  - the tool's pure parts (name normalization, alias and title matching,
    merge that never un-approves, simplification);
  - the validator rules;
  - hit-testing;
  - widget tests for the card with one and with several targets, and for
    deep links;
  - a check in a web build at localhost (`flutter_map` runs on web).

## Decisions (all confirmed by the user as recommended)

- **M1 — Basemap: self-hosted Protomaps PMTiles on R2.**
  - It costs about $0, gets styled to match the lacquer look, and needs no
    new account.
  - **Early check in execution:** confirm that r2.dev serves `Range` requests
    correctly. If it doesn't, fall back to MapTiler's free tier and tell the
    user first.
- **M2 — Streets without a page are not tappable.** Only streets with a page
  are gold and tappable; everything else is plain basemap.
- **M3 — Review of matches.**
  - Exact name matches are auto-approved (about 82).
  - Matches from aliases, event titles, or several targets (about 20–30) come
    to the user as **one review table before anything ships**. Execution
    stops at that table and waits for the user's yes.
- **M4 — Entry points: both** the Sảnh entry and the reverse chip on
  Character and Event detail pages. No Home pill.
- **M5 — The famous-streets-with-no-page backlog (Nguyễn Hữu Cảnh, Lê Hồng
  Phong, Võ Thị Sáu, …) stays out of Cycle M.** It's queued below as its own
  content cycle, because new figures need ĐVSKTT or Viện Sử học sourcing and
  art.

## Execution order

1. **M-A** street tools, validator rules and tests. This ends at the **M3
   review table**, and nothing ships until the user approves it.
2. **M-B** the PMTiles extract, hosted on R2, with the `Range` check first.
3. **M-C** the map screen, with hit-testing and card tests, verified in a web
   build.
4. **M-D** the Sảnh entry and the reverse chip.
5. Publish the street content through the normal dry run → the user's yes →
   real publish. The screen itself waits for the next app build.

## Next cycles (queued)

- **Streets near me** (deferred from M at the user's request). It needs:
  - "while using the app" location permission, used only on the device and
    never sent anywhere;
  - a Play Data safety update;
  - a "Gần tôi" button that centers the map and lists the nearest history
    streets.
- **More cities:** Hà Nội first (its streets are densely named after
  history), then Huế and Đà Nẵng. The M-A tools take a city argument, so each
  new city is mostly data plus a review.
- **A CMS editor for street mappings** (approve, re-target, add aliases),
  instead of editing `hcm.json` by hand.
- **Content cycle for the famous streets with no page yet** (M5): Nguyễn
  Hữu Cảnh first (founder of Saigon, 1698), then Lê Hồng Phong, Võ Thị Sáu,
  Phan Văn Trị, Nguyễn An Ninh, Hoàng Văn Thụ, Trần Văn Giàu. Each needs
  sourcing and art, and each adds itself to the street map once published.
- **Media manifest live via Firestore** (carried over from K5).
- **Carried-over UX audit findings:** particles over text, Chào cờ lyrics
  legibility, swipe-hint timing. See `21fb88b:EXECUTION.md`.
