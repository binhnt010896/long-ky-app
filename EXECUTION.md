# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: Cycle R Wave B is BUILT (2026-10-03), not yet published.** What is
done: the standalone-person code (`bf42c82`), 38 street aliases and 33 new
people and 6 standalone events as text (`c038622`), and all their art
(`ba162df`). The street map goes from **92 to 163 streets**. Images are in
`content/people/<id>/` and `content/events/<id>/`; they are git-ignored, so
they reach the CDN only with the next publish. **Waiting on the user:**
(1) publish content (dry run first), (2) cut the next app release for the new
streets (R5), (3) the phone check, (4) images for the 7 people with none
(Hồ Huấn Nghiệp, Nguyễn Văn Quá, Mai Xuân Thưởng, Trần Tấn, Đặng Như Mai,
Tôn Thất Thiệp, Tôn Thất Đạm; the first two are in Wave B and ship held).
Waves C and D are next, and all their photos are already in place.

Earlier specs: M `cfa220a`, N `92e699f`, O `f56a4d7`, P `9552bb5`, Q `84d5ed8`
(each `<sha>:EXECUTION.md`); what Q shipped: `afe41a8:EXECUTION.md`.

## Audit of the previous plan

Done since the last plan (Cycle Q):
- **Cycle Q built** (`afe41a8`): gold dragon splash art, italic wordmark, and a
  dark Android launch window.
- **Since then:** tile cancellations are no longer reported as fatal crashes
  (`3b266a6`), a privacy-policy link was added to About Long Ký, and the app
  went from 1.1.0+8 to **1.1.2+10** (`2528904`).

**Carried forward (all wait on the user):**
1. The Play closed test (12+ testers, 14 days), the release-build check of the
   street map on a phone, the Data safety form, and the Analytics custom
   definitions.
2. Firestore (still off): the steps in `979cb3f:EXECUTION.md`.
3. Optionally deleting `admin-long-ky.web.app`.

## Cycle R — what the user asked for

> Plan to add more events and characters to our app, so that the street map is
> filled with more data. Also list out images I need to prepare, if it's in
> modern era and actually photographed; otherwise note down to use Higgsfield
> to generate image based on the description of the event/character.

**Confirmed (2026-10-03):**
- **R1 — People with no era are fine.** New figures in the gaps between eras
  (1672–1771, 1300–1413, 1127–1225) need no new eras.
- **R2 — Era rosters stay exactly as they are.** **Every new person is
  standalone.** That includes people who fit inside an existing era's years
  (Trần Văn Giàu, Nguyễn Văn Trỗi…). The era hubs don't grow.
- **R3 — Ambiguous street names are skipped:** Ba Đình, Trường Sơn, Vạn Kiếp,
  Bến Vân Đồn, Hát Giang, Thăng Long. They may later fit a **landmark object
  with its own detail page** (queued).
- **R4 — Hoàng Sa and Trường Sa are skipped.**
- **R5 — Street mapping over the air is parked.** `hcm.json` stays bundled, so
  **the new streets reach phones with the next app release**. The people,
  events and art go out earlier, over the air.
- **R6 — Wave order: A + B this cycle, then C, then D.**

### What I measured (read-only, `build/streets/hcm-ways.json`, 2026-09-30 OSM)

- Old HCMC has **1,646 named streets** without numbers (≈ 2,786 km). **92 are
  mapped today: 23.5 % of the km.** Many of the unmapped names are places or
  flowers, so the ceiling is well under 100 %.

| Wave | What | Streets | Cumulative | Share of km | Photos from you | Higgsfield |
|---|---|---|---|---|---|---|
| now | — | — | 92 | 23.5 % | — | — |
| **A** | Aliases to **existing** people and events | +36 | 123 | 25.0 % | 0 | 0 |
| **B** | Saigon–Gia Định first (33 people, 6 events) | +37 | 160 | 33.4 % | 13 + 1 event | ≈ 72 images, ≈ 145 cr |
| **C** | Older heroes and scholars (≈ 67 people, 4 events) | +68 | 228 | 35.5 % | 1 (+ 🔍 finds) | ≈ 138 images, ≈ 275 cr |
| **D** | The 20th century (55 people) | +56 | 284 | 43.3 % | 55 | ≈ 110 restores, ≈ 220 cr |

### Code facts that shape R-0

- `StreetMatcher` drops any person on no roster (`if (era == null) continue;`
  in `street_matcher.dart`). Street targets carry an era for routing.
- People are routed only as `/era/:slug/figure/:id`. The places that build that
  route are `street_card.dart:14`, `event_figures.dart:74` and `app_router.dart`.
  `CharacterDetailScreen` loads the era (`eraProvider(slug)`).
- Cycle N's precedent for events: `/su-kien/:id` redirects to the era route if
  the event is in an era; otherwise it opens `StandaloneEventScreen`. The street
  validator accepts an event target with no era when it is a standalone event.
- **N3** (a standalone event's `figureIds` must be rostered people) has to
  relax to "any person in `people.json`".

### R-0 — Standalone people (code; mirrors Cycle N)

- **Domain:** a `standalonePeopleIds(eras, people)` helper (the people on no
  roster), next to `standaloneEventIds`.
- **Validator** (`validate_content` and `StreetValidator`):
  - a standalone event's `figureIds` may be **any registry person** (N3
    relaxed);
  - an in-era event's `figureIds` must still be on that era's roster;
  - a street person target with an empty era must be a standalone person;
  - a standalone person needs `avatar` and `fullBody` (real or held), and an
    optional `lifespan` display (`{vi, en}`, e.g. "1650 – 1700"), because their
    page has no era header to date them.
- **Matcher:** a person on no roster gets a target with `era: ''` instead of
  being skipped.
- **App:**
  - a route `/nhan-vat/:id`: it redirects to `/era/<home>/figure/:id` when the
    person is rostered; otherwise it opens a **standalone character screen**
    (the same layout as `CharacterDetailScreen`, with no era palette; the
    lifespan as its kicker; the standalone events the person appears in; the
    reverse street chip);
  - `street_card.dart` routes a person with an empty era to `/nhan-vat/:id`;
  - `event_figures.dart` on a standalone event links to `/nhan-vat/:id`.
- **Media paths:** `people/<id>/avatar.png` and `people/<id>/full.png`, like
  `events/<id>/…`. The manifest and ledger already walk `people.json`; check
  that the CMS media library lists them.
- **Old builds:** they get the new `people.json` and standalone events in the
  pack. Unrostered people are simply unused there. A standalone event's figure
  strip resolves through the registry, so test it on a 1.1.2 build. Old builds
  never see the new streets (their mapping is bundled).
- **Discoverability:** standalone people are reachable from the street map,
  from the figure strip of a standalone event, and from search *if* search
  covers people (check during R-0). A "Danh nhân" directory is queued, not in R.
- **Tests:**
  - validator rules, both accept and reject;
  - the matcher emitting `era: ''`;
  - the route redirect, for a rostered and a standalone person;
  - the standalone screen with a held portrait and a real one;
  - the street card's route.

### R-1 — Wave A: aliases (no new content, no art)

Added to `content/streets/aliases.json`. Every alias match goes through the M3
review table and is approved by the user.

- **People:**
  - Hùng Vương → `vua-hung`; Phan Chu Trinh / Phan Tây Hồ → `phan-chau-trinh`;
    Phan Sào Nam → `phan-boi-chau`;
  - Lê Thánh Tôn → `le-thanh-tong`; Trần Nhân Tôn → `tran-nhan-tong`;
    Trần Quốc Tuấn → `tran-hung-dao`;
  - Đề Thám, Ngô Thời Nhiệm, Nguyễn Thiệp, Phạm Cự Lượng;
  - Đinh Bộ Lĩnh → `dinh-tien-hoang`; Trưng Nữ Vương / Trưng Vương;
  - Bãi Sậy → `nguyen-thien-thuat`; Nhật Tảo → `nguyen-trung-truc`;
  - Song Hành Võ Nguyên Giáp.
- **Events:**
  - Diên Hồng, Chương Dương / Bến Chương Dương, Đống Đa, Lam Sơn / Công trường
    Lam Sơn, Hồng Đức, Tây Sơn, Yên Thế, Đông Du;
  - Ba Tháng Hai → `dang-cong-san-ra-doi`; Tân Trào; Công trường Mê Linh;
  - Bình Giã / Đồng Xoài / Ba Gia → `danh-bai-chien-tranh-dac-biet`;
  - Núi Thành / Bàu Bàng → `chien-tranh-cuc-bo`;
  - Nữ Dân Công → `dien-bien-phu`.
- **Never alias these:**
  - *Nguyễn Ảnh Thủ* is not Nguyễn Ánh.
  - *Lê Văn Lương* is not Lê Văn Duyệt.
  - *Trấn Đại Nghĩa* (an OSM typo) waits for `tran-dai-nghia` in Wave D.
  - *Trần Khắc Chân* waits for `tran-khat-chan` in Wave C.

### R-2 — Wave B people (33, all standalone)

Added through the CMS People form: name, epithet, bio (vi/en), lifespan, and the
photo-fidelity box where it applies.
- **The Gia Định founding and Hà Tiên:** Nguyễn Phúc Chu, Nguyễn Hữu Cảnh,
  Nguyễn Cửu Vân, Nguyễn Cửu Đàm, Mạc Cửu, Mạc Thiên Tích (with the alias
  Chiêu Anh Các), Nguyễn Cư Trinh.
- **The Gia Định scholars and canals:** Trịnh Hoài Đức, Võ Trường Toản, Ngô
  Nhân Tịnh, Lê Quang Định, Thoại Ngọc Hầu.
- **The Southern resistance, 1860–1885:** Nguyễn Đình Chiểu, Phan Văn Trị,
  Thủ Khoa Huân, Thiên Hộ Dương, Hồ Huấn Nghiệp, Huỳnh Mẫn Đạt, Phan Văn Hớn,
  Nguyễn Văn Quá.
- **The 20th century:** Trần Văn Giàu, Lý Tự Trọng, Châu Văn Liêm, Võ Văn
  Tần, Nguyễn Thị Thập, Võ Thị Sáu, Trần Văn Ơn, Nguyễn Văn Trỗi, Lê Thị
  Riêng, Út Tịch, Trần Bạch Đằng, Huỳnh Tấn Phát, Nguyễn Hữu Thọ.

**Sourcing and tone:**
- ĐVSKTT where it covers a person. It ends in 1675, so later figures cite
  *Đại Nam thực lục*, *Gia Định thành thông chí* or the *Cương mục*, named
  honestly.
- Modern people: Gov sources (Viện Sử học, dangcongsan.vn, baotanglichsu).
- History, not politics: short, dated, record-only bios.

**Portraits:** 📷 and 🔍 people ship with `placeholder: "portrait-held"` until
their images are ready.

### R-3 — Wave B events (6, all standalone)

Each has a citation, a `year.value` and a hero at `events/<id>/hero.png`.

| Event | Year | Street(s) | Figures |
|---|---|---|---|
| `nguyen-huu-canh-lap-phu-gia-dinh` | 1698 | (gives context) | Nguyễn Phúc Chu, Nguyễn Hữu Cảnh |
| `mac-cuu-dang-ha-tien` | 1708 | (gives context) | Mạc Cửu, Mạc Thiên Tích |
| `dap-luy-ban-bich` | 1772 | Lũy Bán Bích | Nguyễn Cửu Đàm |
| `dao-kenh-vinh-te` | 1819–1824 | Châu Vĩnh Tế | Thoại Ngọc Hầu |
| `khoi-nghia-hoc-mon` | 1885 | (gives context) | Phan Văn Hớn, Nguyễn Văn Quá |
| `dac-cong-rung-sac` | 1966–1975 | Rừng Sác (verify the naming resolution) | — |

`relatedEventIds` link them to the existing era events where they belong (for
example, `nghia-quan-nam-ky` ↔ the Southern resistance figures' events).

### R-4 — Art (`docs/street-fill-images.md` → Wave B)

- **🎨 Higgsfield:**
  - 12 people × (avatar + full body);
  - 5 event heroes;
  - every image reviewed before the user sees it;
  - generations paced, never a multi-reference img2img batch.
- **📷 the user drops photos** in `content/people/<id>/source.jpg`, with
  `credit.txt`. Each is restored and colourised with a per-face A/B check, and
  captioned "Ảnh tư liệu" or "Ảnh tư liệu · phục chế màu".
- **🔍** the user checks 8 names and leaves `source.jpg`, `altar.jpg` or
  `none.txt`.
- **Cost:** about 72 images, roughly **145 credits** before re-rolls.

### R-4b — Photo intake (2026-10-03): rules for processing the user's images

All Wave A–D photos are in `content/people/<id>/` (file names are
`<id>.<ext>`, and `<id>-reference.<ext>` where a second image exists), except
the **7 empty folders**: `ho-huan-nghiep`, `nguyen-van-qua`, `mai-xuan-thuong`,
`tran-tan`, `dang-nhu-mai`, `ton-that-thiep` and `ton-that-dam`.

Rules for every image:
1. Blurry or pixelated: enhance. Black and white: colourise.
2. A file with the suffix `-reference` is a second image used to restore
   features the main portrait lost (old, blurry, missing detail). Five exist:
   Tăng Bạt Hổ, Thủ Khoa Huân, Nguyễn Thượng Hiền, Nguyễn Duy Hiệu, Đinh Công
   Tráng.
3. If the image is too blurry to restore, Higgsfield re-imagines the portrait
   from the blurry photo, keeping the likeness.
4. Remove any watermark, subtitle or caption that is not part of the picture.
5. Keep the hairstyle, background and outfit true to the person's era.
6. A person with no image at all gets no portrait on the character page and a
   placeholder avatar (the held-portrait mechanism); the street still lights up.

Still true: every restored face is checked against the original (per-face A/B),
and no face is invented for a photographed person. Reminder: the Higgsfield
rule "never multi-reference img2img batches" applies; upload references one at
a time and verify the bytes.

### R-5 — The street pipeline

- `suggest.dart --offline`, then the M3 review of every alias and new match,
  then `build_geometry.dart`.
- `suggest.dart` gains a **coverage line** (streets, km, share).
- `validate_content`, the mobile tests, analysis.

### R-6 — Ship

1. **Content first, over the air.** Through the CMS publish (dry run first):
   people, events and art. The user runs it.
2. **Streets with the next app release** (R5): the new bundled `hcm.json`,
   plus the R-0 code. Bump the version and build the bundle; the user uploads
   it.
3. **On the phone:**
   - the newly gold streets;
   - a tap on each kind: an alias to a person, an alias to an event, a
     standalone person, a held portrait;
   - the reverse street chip on a standalone person's page;
   - a standalone event's figure strip.

### R-7 — Commit on `main` and update this file

## Next cycles (queued — not to be planned until the user says)

- **Wave C** (next), then **Wave D**.
- **A landmark object and landmark detail page**, for Ba Đình, Trường Sơn,
  Vạn Kiếp… (R3).
- Street mapping over the air (parked, R5).
- A "Danh nhân" directory for standalone people.
- Wave E: local Southern martyrs, scientists and artists, Tô Hiến Thành,
  Nguyễn Hữu Cầu.
- Hoàng Sa / Trường Sa (R4).
- More landmarks; an in-house lacquer base-map style; streets near me; more
  cities; a CMS editor for street mappings; the carried-over UX audit findings
  (`21fb88b:EXECUTION.md`).
