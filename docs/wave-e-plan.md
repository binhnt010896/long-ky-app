# Wave E plan: scientists, artists, writers and foreign friends; faster street map

Planning only. Nothing here is built yet.

Street mapping over the air is already built (see `EXECUTION.md`, Wave E), so once
the next app release ships, everything below reaches phones by publish alone.

---

## Part 1. New people for the street map

**Scope rule (user, 2026-10-05):** scientists, doctors, artists and writers are in, as
long as they are Vietnam's own. Foreigners are in **only when they did something for
Vietnam** (Pasteur and Morrison are the examples given). World figures with no
Vietnam link stay out.

Every name below is an HCMC street that exists in our OSM snapshot and is **not
mapped yet**. Same rules as Cycle R:
- Each person is standalone.
- Bios are short, dated and record-only.
- 📷 = you supply a photo. 🎨 = pre-photographic, generated with Higgsfield.
- Portraits are waist-up.

### E1. Foreign friends of Vietnam (8, all 📷 or 🎨 from period photos)
| Street | Person | Why Vietnam honours them |
|---|---|---|
| Yersin | Alexandre Yersin (1863–1943) | Founded Đà Lạt, ran the Nha Trang Pasteur Institute, lived and died in Vietnam |
| Calmette | Albert Calmette (1863–1933) | Founded the Saigon Pasteur Institute in 1891 |
| Pasteur | Louis Pasteur (1822–1895) | Named via the Pasteur Institutes in Saigon and Nha Trang (he never came; say so in the bio) |
| Alexandre de Rhodes | Alexandre de Rhodes (1593–1660) | Systematised Quốc ngữ; the 1651 dictionary |
| Morison | Norman Morrison (1933–1965) | Self-immolated at the Pentagon in protest at the war; honoured as "Mo-ri-xơn" |
| Raymondienne | Raymonde Dien (1929–2022) | Lay on the rails in 1950 to stop a French arms train |
| Bertrand Russell | Bertrand Russell (1872–1970) | The 1966–67 Russell Tribunal on the war |
| Luther King | Martin Luther King Jr. (1929–1968) | His 1967 "Beyond Vietnam" speech against the war (included: user, 2026-10-05) |

**Out (world figures, no Vietnam link):** Einstein, Galileo Galilei, Tagore.

### E2. Scientists, doctors and engineers (19, all 📷)
Lê Văn Thiêm · Tôn Thất Tùng · Hồ Đắc Di · Đặng Văn Ngữ · Lương Định Của ·
Kha Vạn Cân · Đỗ Xuân Hợp · Ngụy Như Kon Tum · Nguyễn Văn Hưởng · Đặng Thùy Trâm ·
Nguyễn Xiển · Nguyễn Văn Huyên · Nguyễn Khắc Viện · Lê Đình Thám · Phạm Huy Thông ·
Trần Văn Khê (musicologist) · Hoàng Minh Giám · Ca Văn Thỉnh · Huỳnh Văn Bánh

### E3. Painters, sculptors and composers (9, all 📷)
Tô Ngọc Vân · Nguyễn Gia Trí · Bùi Xuân Phái · Nguyễn Sáng · Diệp Minh Châu ·
Trịnh Công Sơn · Hoàng Việt · Nguyễn Văn Tý · Đỗ Nhuận

### E4. Modern writers, poets and scholars (31, 📷)
Nam Cao · Thạch Lam · Ngô Tất Tố · Thế Lữ · Xuân Diệu · Huy Cận · Hàn Mặc Tử · Tản Đà ·
Nguyễn Tuân · Hoàng Cầm · Vũ Trọng Phụng · Lưu Trọng Lư · Hoài Thanh · Chế Lan Viên ·
Xuân Quỳnh · Nguyễn Đình Thi · Tố Hữu · Đặng Thai Mai · Vũ Ngọc Phan · Hồ Biểu Chánh ·
Nguyễn Hiến Lê · Dương Quảng Hàm · Nguyễn Đổng Chi (OSM also has the misspelling
"Nguyễn Đồng Chi": alias it) · Đào Duy Anh · Trương Vĩnh Ký · Huỳnh Tịnh Của ·
Nguyễn Văn Vĩnh · Phan Kế Bính · Nguyễn An Khương · Cô Giang · Cô Bắc

**Skipped (user, 2026-10-05):** Trần Trọng Kim, the 1945 prime minister under Japan.
His street stays unmapped.

### E5. Classical poets and pre-modern figures (15, 🎨 Higgsfield)
Bà Huyện Thanh Quan · Đoàn Thị Điểm · Hồ Xuân Hương · Nguyễn Khuyến · Tú Xương ·
Đặng Trần Côn · Nguyễn Gia Thiều · Phạm Đình Hổ · Cao Bá Nhạ · Học Lạc · Nhiêu Tâm ·
Bùi Hữu Nghĩa · Nguyễn Thông · Vũ Tông Phan · Yết Kiêu
plus **Tô Hiến Thành** and **Nguyễn Hữu Cầu**, already queued (17 in all).

### Still deferred
- **Local Southern martyrs** (Nguyễn Thị Rành, Nguyễn Văn Khạ, Nguyễn Văn Bứa, Đồng Văn
  Cống, Trần Quang Quờn, Lê Văn Việt…) are some of the longest unmapped streets. Each
  needs a Gov or provincial source first.
- **Ambiguous names and landmarks** (Ba Đình, Trường Sơn…) wait for the landmark object.

**Totals:** about 84 people, about 85 streets (with the alias). Photos from you: about
67. Higgsfield: about 17 painted plus about 70 restorations, roughly **300 credits**.

**Order, smallest first:** E1 → E3 → E2 → E5 → E4. Same pipeline as Wave D:
1. Text, then commit.
2. Photo drop folders plus a README list.
3. Restore or generate, and review against each source.
4. Wire, push `main`, publish.

---

## Part 2. Street map loading: findings and plan

### What I measured (2026-10-05, from this Mac in Vietnam)
- **Every media request goes to `pub-…r2.dev`,** Cloudflare's development URL. It is
  not edge-cached (no `cf-cache-status`), and Cloudflare rate-limits it.
  - Time to first byte is **230–440 ms per request**.
  - The street geometry (159 KB) takes about 0.3–0.5 s.
- **The basemap is a 36.9 MB PMTiles archive** with 9,095 tiles, zoom 10–15, about 4 KB
  each. It is read over the network with **one HTTP range request per tile**.
- **Before the first basemap tile can draw**, the app makes a chain of serial requests:
  1. the archive header,
  2. the root directory, then the 19 KB leaf directory,
  3. then the tiles, at **4 at a time** (the `vector_map_tiles` default).

  A first screen needs roughly 20–40 tiles across two zoom levels. That is roughly
  **3–6 s on a good connection**, and more on 4G.
- **The archive is re-opened every time** the map screen opens, because
  `PmTilesVectorTileProvider.fromSource` lives in the screen's State. The
  header-and-directory chain is paid again on every visit.
- **The tile disk cache sits in the OS temp directory**
  (`getTemporaryDirectory()/.long_ky_basemap_v2`). Android may clear it at any
  time, which turns a return visit back into a first visit.
- **The tiles are drawn into images by Dart** (`layerMode: raster`), labels
  included. On a mid-range phone this is likely a second cost. Not measured yet.
- **Not the bottleneck:** our own geometry. It is 285 streets, 1,323 lines, 6,054
  points, plus a 1,059-point boundary. It is small, but the whole polyline list is
  rebuilt on every `setState`.
- **The whole screen waits on the geometry download** (spinner) the first time.

### Plan, in order (each step measured before and after)

**S0. Measure on your phone** (no behaviour change)
- Add timing telemetry:
  - `map_open → geometry_ready`,
  - `→ first_basemap_tile`,
  - `→ viewport_complete`,
  - plus per-tile fetch latency.
- Take one DevTools CPU profile on the Android phone to split network wait from raster time.

**S1. Serve media through a real domain with the Cloudflare cache** (the biggest win; needs you)
- **You do this:**
  1. Buy a domain in Cloudflare → Domain Registration. It's at cost: `.com` about
     US$10.46 a year, `.app` about US$14.20 a year.
  2. R2 → `long-ky-content` → Settings → Custom Domains → connect `media.<domain>`.
  3. Add a Cache Rule for that hostname: "Eligible for cache", respect the origin's
     `Cache-Control`.
- **I do this:**
  1. Switch the base URL in the app, the CMS and the publish tooling.
  2. Verify `cf-cache-status: HIT` on range reads.
  3. Keep `r2.dev` on until old app versions are gone.
- Point a custom domain (e.g. `media.longky.app`) at the R2 bucket.
- Add a Cache Rule that caches everything under `/media/` and `/content/packs/`. Range
  requests are then served from the edge.
- Expected: per-request time drops from about 350 ms to tens of ms. Every image in the
  app gets faster, not just the map.
- Switch `kContentMediaBase` (already flagged "switch before launch" in
  `content_assets.dart`). This needs an app release, so do it before or with the
  next one.
- `latest.json` stays `no-cache`.

**S2. App-side quick wins** (one release)
- Open the PMTiles archive **once per app run**, in a Riverpod provider, and **warm it
  during the splash**: header plus directories. The map screen then starts at the tiles.
- Raise tile `concurrency` from 4 to about 8.
- Move the tile disk cache from the temp directory to the app support directory, with
  a longer TTL. The suffix rule stays: bump it when the theme changes.
- Prefetch the street geometry at the splash through `MediaPrefetcher`. It is 159 KB
  and already cache-versioned, so the map opens with the gold streets immediately.
- Show the gold streets and the boundary mask straight away, with the basemap fading
  in under them. Today the whole screen waits on the geometry.
- Build the polyline list once per selection, not on every rebuild.

**S3. A lighter basemap**
- Re-extract the PMTiles at **max zoom 14** and let the renderer over-zoom for 15–17.
- Drop the layers we hide anyway: `pois`, `water_label_ocean`, `places_subplace`,
  `boundaries_country`.
- Likely about half the size or less, and fewer tile reads per screen.
- Ships by publish (it's media), no app release.

**S4. Optional offline basemap**
- After S3, download the whole archive once in the background, Wi-Fi only, into app
  storage. Read it locally from then on: zero network on the map.
- Trade-off: the download size, roughly 15–20 MB after S3.

**S5. Rendering, only if S0 shows raster time matters**
- Cap label layers at lower zooms.
- Try `VectorTileLayerMode.vector` against `raster` on the phone.
- Tune `memoryTileCacheMaxSize`.

**Expected outcome:**
- After S1 and S2: a first open in about 1–1.5 s with the streets visible instantly,
  and repeat opens near-instant.
- After S3 and S4: the map works offline.

---

### S1 status (2026-10-05)
- Domain: `media.binh-nt.dev` is live on Cloudflare with the Free plan. The app and CMS defaults now point at it.
- Measured: cached range reads (HIT) come back in about 0.2 s, against about 0.34 s from `r2.dev`.
- **To fix in the Cloudflare cache rule:** `/content/latest.json` must stay uncached. The rule
  currently applies a 4-hour edge TTL to it (origin says `no-cache`), which would delay every
  publish by up to 4 hours. Exclude it with "Bypass cache" or use "Respect origin".

### S2 status (2026-10-05): built, not yet measured on a phone
- Base map archive opened once per app run (`streetBasemapProvider`), and warmed with the street
  geometry in the background at the splash (never awaited).
- Tile concurrency 4 → 8; tile TTL 30 → 90 days; cache moved from the temp directory to the app
  support directory, in a folder named for the extract's version (a republished extract starts a fresh
  cache by itself).
- The ~1,300 resting polylines are one widget built once per data; selecting a street or typing in
  search no longer rebuilds them.
- Still to do: S0 timing telemetry on the phone, then S3 (lighter extract) if the numbers want it.
