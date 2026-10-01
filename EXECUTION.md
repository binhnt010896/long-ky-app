# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: Cycle P is BUILT on `m-cycle` (landmarks, the closer
opening view, the centred search text) together with the web fix for the base
map (W-1). Seen working in a release web build; the phone check (P-6) is the one
thing left, because the phone was not connected. Decisions P1 "patch", P2, P3
and P4 were all confirmed as recommended.**

Cycles M, N and O are built and pushed on branch `m-cycle`, kept separate from
`main` at the user's request. Their specs: `cfa220a:EXECUTION.md` (M),
`92e699f:EXECUTION.md` (N), `f56a4d7:EXECUTION.md` (O). The full diagnosis of
the web problem is in this file's previous version (git history).

## What was built (2026-10-01)

- **P-1 Landmarks:** `content/streets/hcm.json` has `landmarks` (six, in label
  priority order) and `start` (centre 10.7770, 106.6990, zoom 13). Positions
  come from OpenStreetMap data (Nominatim for the market, the palace and the
  lake; the base map's own copy of OSM for the cathedral, Landmark 81 and the
  airport — Overpass was down). For the airport the point is the international
  terminal (T2), not the runway middle. `StreetLandmark`/`StreetStart` in
  `core_domain`; the validator checks ids, both names, and that every landmark
  and the start centre lie inside the old-city boundary and the start zoom is
  10–17. `suggest.dart` keeps both when it rewrites the file.
- **P-2 Drawing:** `street_landmarks.dart` — gold-ringed badges with a thin
  icon, names beneath, following the VI/EN switch. Badges are 22 px below zoom
  14 and 28 px from it (at zoom 13 four of them are a few pixels apart). A name
  hides when it would overlap a higher-priority name or any badge, or would be
  clipped by the screen edge. Hidden below zoom 11. Touches pass straight
  through to the gold streets.
- **P-3 Opening view:** opens at `start`; with no `start` it still fits the
  whole camera lock.
- **P-4 Search box:** hint and typed text centred (a test fails without the fix).
- **W-1 Web fix:** `third_party/vector_map_tiles` (8.0.0 + a disk-cache no-op and
  the in-page queue on web, plus a one-time log of a failing tile), wired by
  `dependency_overrides`. The base map now draws in a release web build.

### Two more things found on the way

1. **Every label of the stock Protomaps theme was silently missing — on every
   platform, not only web.** Its `text-field` is a long expression (`format`,
   `is-supported-script`) that `vector_tile_renderer` 5.2.1 doesn't understand,
   so it drops the text. The base map showed roads and water but no names. Fixed
   by giving every label layer a plain `["get","name"]` (OSM's own name, which
   in Vietnam is Vietnamese), with a test that fails if an unsupported text
   expression comes back. Now street, canal, river and neighbourhood names show.
2. **The 37 MB base map (and the street GeoJSON) were being bundled into the
   app:** `pubspec.yaml` listed the whole `assets/content/streets/` folder, and
   the git-ignored files sitting in it locally went along. That is why the
   release APK was 118 MB. The three files the app really bundles are now
   listed one by one.

### Seen in a release web build (375×812), screenshots sent to the user

- Opens on the city centre at zoom 13; gold streets over roads, canals and the
  Sài Gòn river; Chợ Bến Thành and Landmark 81 named, the others as badges.
- Zoom 14: Dinh Độc Lập's name appears as space allows. Zoom 16: buildings,
  Notre-Dame's name.
- The search hint sits on the field's centre.
- Camera lock and zoom 10 minimum unchanged; no sea or ocean labels, no
  national borders. At zoom 10 on a tall phone the view shows some land beyond
  the old city (Gò Công, Bình Đại), unchanged from Cycle M.
- Console: no errors.
- **Not measured:** the size of each range request (the browser hides it for a
  cross-origin file); 51 range requests were made, none for the whole file.

### Still to do

1. **P-6 on the phone** (release APK, once connected): smooth pan and zoom,
   labels showing, the landmarks readable, first paint within a few seconds.
2. A possible tweak: the stock theme prints lots of "KHU PHỐ n" labels. They are
   real OSM names but add clutter; hiding that one layer is a one-line change if
   the phone view feels busy.

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

> 1. Put landmarks where they belong: Bến Thành Market, Independence Palace,
>    Tân Sơn Nhất Airport, Notre-Dame Cathedral, the Turtle Lake, Landmark 81.
> 2. By default, zoom in a bit; currently too zoomed out.
> 3. The search placeholder "Tìm tên đường" sits too close to the top of the
>    box; it should be vertically centred.

The full plan (steps P-1…P-7, W-1 and decisions P1–P4) is at `9552bb5:EXECUTION.md`.

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
