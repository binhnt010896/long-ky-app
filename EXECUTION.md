# EXECUTION PLAN

> **Workflow:** sessions are split into **PLANNING** (draft events, sources,
> this file) and **EXECUTION** (build it). This file is **rewritten in full**
> every planning cycle and always describes the *current* planned era only.
>
> **Current target:** Era 31 — **Kháng chiến chống Mỹ, cứu nước (1954–1975)**,
> ending at reunification 30/4/1975.
>
> **Precondition to execute:** the user has dropped all event + character images
> into the folders listed in Step 6. Structural template to copy is
> `content/eras/dien-bien-phu.json` (era 30). Sources are Vietnam-Gov and the
> narrative stays on the mainstream Party-led account (see memory
> `modern-era-sourcing-gov-pov`, `camera-photo-fidelity`, `stay-close-to-dvsktt`).

---

## 0. Identifiers

- **New period id:** `khang-chien-chong-my` — order **12**, 1954–1975, accent `#8a2f2a` (deep war-red; tune if too close to era-30 `#b23a2e`).
- **Era slug/id:** `dai-thang-mua-xuan` — order **30**, period `khang-chien-chong-my`.
- **Primary source (era):** `Lịch sử kháng chiến chống Mỹ, cứu nước (1954–1975)` / author `Viện Lịch sử Quân sự Việt Nam`.
- Palette: accent `#8a2f2a`, particle `#e0b23e`, scene ramp like era 30 (oxblood → gold), all 6-digit hex (validator rejects 8-digit).

## 1. Events (11) — VERIFY BEFORE WRITING PROSE

Each becomes one event object mirroring era 30 (fields: id, slug, figureIds,
details[vi/en ~1 para], order, kind:"historical", year{display,value,approximate:false},
title, summary, body[shorter], pullQuote{text,attribution}, hero{…events/<slug>.png}, citation).

| # | slug | date (value) | title vi | figureIds | citation work / section / author |
|---|------|------|----------|-----------|-------------------|
| 0 | `dat-nuoc-chia-doi` | 1954–1959 (1954) | Đất nước tạm chia hai miền | ho-chi-minh | *Lịch sử Việt Nam* / "Miền Nam dưới chế độ Mỹ – Diệm; Luật 10/59" / Viện Sử học |
| 1 | `dong-khoi` | 1959–1960 (1960) | Phong trào Đồng khởi | le-duan, nguyen-thi-dinh | *Lịch sử kháng chiến chống Mỹ, cứu nước* / "Nghị quyết 15 và phong trào Đồng khởi" / Viện Lịch sử Quân sự Việt Nam |
| 2 | `danh-bai-chien-tranh-dac-biet` | 1961–1965 (1963) | Đánh bại "Chiến tranh đặc biệt" | vo-nguyen-giap | Viện LSQS / "Chiến thắng Ấp Bắc; phá 'ấp chiến lược'" |
| 3 | `chien-tranh-cuc-bo` | 1965–1967 (1965) | "Chiến tranh cục bộ" và chống chiến tranh phá hoại | vo-nguyen-giap | Viện LSQS / "Vạn Tường, hai mùa khô; miền Bắc đánh trả không quân Mỹ" |
| 4 | `tet-mau-than-1968` | 1968 (1968) | Tổng tiến công và nổi dậy Xuân Mậu Thân 1968 | le-duan | *Lịch sử Đảng CSVN* / "Cuộc Tổng tiến công và nổi dậy 1968" / Viện Lịch sử Đảng |
| 5 | `bac-ho-qua-doi` | 2/9/1969 (1969) | Chủ tịch Hồ Chí Minh từ trần và bản Di chúc | ho-chi-minh | *Hồ Chí Minh Toàn tập* / "Di chúc của Chủ tịch Hồ Chí Minh (1969)" / Hồ Chí Minh |
| 6 | `duong-truong-son` | 1959–1972 (1971) | Đường Trường Sơn và đánh bại "Việt Nam hoá chiến tranh" | le-duan, vo-nguyen-giap | Viện LSQS / "Đường Hồ Chí Minh; Đường 9 – Nam Lào 1971" |
| 7 | `dien-bien-phu-tren-khong` | 12/1972 (1972) | "Điện Biên Phủ trên không" | vo-nguyen-giap | Viện LSQS / "12 ngày đêm bảo vệ Hà Nội (12-1972)" |
| 8 | `hiep-dinh-paris` | 27/1/1973 (1973) | Hiệp định Paris | nguyen-thi-binh | *Hiệp định Paris về chấm dứt chiến tranh, lập lại hoà bình ở Việt Nam (1973)* / Viện Sử học |
| 9 | `chien-dich-tay-nguyen` | 3/1975 (1975) | Chiến dịch Tây Nguyên; giải phóng Huế – Đà Nẵng | van-tien-dung, vo-nguyen-giap | Viện LSQS / "Chiến dịch Tây Nguyên (Buôn Ma Thuột); Huế – Đà Nẵng (3-1975)" |
| 10 | `chien-dich-ho-chi-minh` | 30/4/1975 (1975) | Chiến dịch Hồ Chí Minh — Đại thắng mùa Xuân 1975 | le-duan, van-tien-dung | Viện LSQS / "Chiến dịch Hồ Chí Minh, giải phóng Sài Gòn 30-4-1975" |

**Pull-quotes (authentic, attribute honestly):**
- 0: "Nước Việt Nam là một, dân tộc Việt Nam là một." — Hồ Chí Minh
- 1: về phong trào Đồng khởi Bến Tre (1960) / "Đội quân tóc dài" (Nguyễn Thị Định)
- 2: "Ấp Bắc — nơi chôn vùi chiến thuật 'trực thăng vận', 'thiết xa vận'." (assessment)
- 3: về thất bại của 'Chiến tranh cục bộ' (assessment, Viện LSQS)
- 4: về ý nghĩa Mậu Thân 1968 làm lung lay ý chí xâm lược (assessment)
- 5: "Cuộc kháng chiến chống Mỹ, cứu nước… nhất định thắng lợi hoàn toàn. Đó là một điều chắc chắn." — Hồ Chí Minh, Di chúc (1969)
- 6: "Không có gì quý hơn độc lập, tự do." — Hồ Chí Minh (17-7-1966)
- 7: về "Điện Biên Phủ trên không" 12-1972 (assessment)
- 8: về Hiệp định Paris 1973 — Mỹ rút quân, tôn trọng độc lập, chủ quyền, thống nhất, toàn vẹn lãnh thổ VN
- 9: "Một ngày bằng hai mươi năm." (assessment về nhịp độ tiến công mùa Xuân 1975)
- 10: "Thần tốc, thần tốc hơn nữa; táo bạo, táo bạo hơn nữa…" — Đại tướng Võ Nguyên Giáp (điện, 4-1975)

> Do NOT cite a source for a quote it did not originate (memory `folk-vs-chronicle-attribution`).

## 2. Figures — add to `content/people.json` (append before closing `]`)

Existing `ho-chi-minh`, `vo-nguyen-giap` are referenced (no new file). **New (4)** — avatar 1:1 + fullBody 2:3, paths under `eras/dai-thang-mua-xuan/characters/`:

| id | name vi | epithet vi (one line) |
|----|---------|-----------------------|
| `le-duan` | Lê Duẩn | Bí thư thứ nhất; kiến trúc sư đường lối kháng chiến chống Mỹ |
| `nguyen-thi-dinh` | Nguyễn Thị Định | Nữ tướng đầu tiên; "Đội quân tóc dài", Đồng khởi Bến Tre |
| `van-tien-dung` | Đại tướng Văn Tiến Dũng | Tư lệnh Chiến dịch Hồ Chí Minh 1975 |
| `nguyen-thi-binh` | Nguyễn Thị Bình | Trưởng đoàn Chính phủ CMLTCHMNVN ký Hiệp định Paris |

Bio ~4–5 sentences each, Gov POV; avatar+fullBody blocks exactly like era-30 figures.

## 3. `content/periods.json`

Append one period object after `khang-chien-chong-phap` (order 11) → the new
`khang-chien-chong-my` order 12 block (title/kicker/subtitle/yearRange 1954–1975/
accent `#8a2f2a`/cover `periods/khang-chien-chong-my.png`). Kicker idea:
"ĐÁNH CHO MỸ CÚT, ĐÁNH CHO NGUỴ NHÀO" or milder "BẮC – NAM SUM HỌP".

## 4. `content/eras/dai-thang-mua-xuan.json`

Create by copying era-30 structure. Fill: era meta (title "Kháng chiến chống Mỹ,
cứu nước", kicker, subtitle, overview ~1 long para vi+en), yearRange 1954–1975,
palette, cover `eras/dai-thang-mua-xuan/cover.png`, scene sky (+ optional
`"video":"eras/dai-thang-mua-xuan/cover.mp4"` **only if** an animated cover is
provided), primarySource (§0), characters[] = the 6 refs, events[] = the 11 above.

## 5. `content/index.json`

Append `"dai-thang-mua-xuan"` to `eras` (→ 31 entries).

## 6. Assets — PROVIDED (currently in `content/eras/khang-chien-chong-my/`)

**Folder rename first:** assets were dropped into `content/eras/khang-chien-chong-my/`,
but the era slug/folder is `dai-thang-mua-xuan`. Execution step: move the folder →
`content/eras/dai-thang-mua-xuan/` and **delete the `.DS_Store` files** in
`characters/` and `events/` (not assets). (If the user confirms the slug should
instead become `khang-chien-chong-my`, skip the rename and change slug refs
throughout — see §0.)

### Restore/colorize rules (user, this cycle)
- **Black-and-white → colorize + enhance** (faithful, period-accurate colour).
- **Already colour → enhance only** for a clearer/sharper image (no recolour).
- **Single-file characters** (no `-avatar`/`-full` suffix) → use the ONE image for
  **both** avatar and full; **crop the avatar generously, NOT tight** (head +
  shoulders with breathing room).
- Pipeline safety (memory `higgsfield-restore-pitfalls`): PUT uploads one file at a
  time (never a bash-array loop) and verify stored bytes; **NEVER** multi-request
  img2img batch; pace around 429s. Camera-fidelity pinned — A/B every restored
  figure/photo vs its original before placing; delete raw drop-ins afterward.
- Final specs: avatar **800×800** (1:1), fullBody **1000×1500** (2:3), event heroes
  **≤1500px** wide PNG.

### Characters — provided (7 files, 4 figures)
| file | state | treatment → output |
|------|-------|--------------------|
| `le-duan.png` (1028×1500) | **B&W, SINGLE FILE** | colorize+enhance → **both** `le-duan-avatar.png` (800², generous crop) **and** `le-duan-full.png` (1000×1500) |
| `nguyen-thi-binh-avatar.jpg` (2100×2624) | B&W | colorize+enhance → avatar 800² |
| `nguyen-thi-binh-full.png` (277×578) | colour, tiny | enhance + heavy upscale → full 1000×1500 |
| `nguyen-thi-dinh-avatar.jpg` (334×399) | B&W, tiny | colorize+enhance+upscale → avatar 800² |
| `nguyen-thi-dinh-full.jpeg` (1024×1451) | B&W | colorize+enhance → full 1000×1500 |
| `van-tien-dung-avatar.jpg` (500×732) | B&W | colorize+enhance+upscale → avatar 800² |
| `van-tien-dung-full.jpg` (492×650) | B&W | colorize+enhance+upscale → full 1000×1500 |

### Events — provided (11 files)
- **B&W → colorize+enhance:** `bac-ho-qua-doi.png` (400×370, upscale), `chien-dich-tay-nguyen.jpg` (1920×1080), `danh-bai-chien-tranh-dac-biet.png` (770×493), `dien-bien-phu-tren-khong.png` (870×539), `dong-khoi.jpg` (665×485), `duong-truong-son.jpg` (600×400), `hiep-dinh-paris.jpg` (1600×1016), `tet-mau-than-1968.jpg` (500×329, upscale).
- **Colour → enhance only:** `chien-dich-ho-chi-minh.png` (1600×1078), `chien-tranh-cuc-bo.png` (350×516, upscale), `dat-nuoc-chia-doi.jpg` (1600×1003).
- Re-save each as `events/<slug>.png` (source extensions are mixed jpg/png/jpeg).

### NOT provided → generate (era-30 method)
- `cover.png` + `scene/sky.png`: ONE lacquer scene (painterly realism, full-bleed,
  no frame — memory `art-style-painterly-realism`), **1600×1194** (4:3), copied to
  both. Subject: 1975 reunification / Chiến dịch Hồ Chí Minh (tanks at Dinh Độc
  Lập, red flag), oxblood + gold lacquer. **Static** — no `cover.mp4` provided, so
  no `video` field this era (memory `static-art-default`).
- `content/periods/khang-chien-chong-my.png`: **1200×1200** crop of the cover.

## 7. `apps/mobile/pubspec.yaml`

Add the 4 asset-folder lines (or images 404 in-app — memory `era-assets-need-pubspec`):
```
    - assets/content/eras/dai-thang-mua-xuan/
    - assets/content/eras/dai-thang-mua-xuan/scene/
    - assets/content/eras/dai-thang-mua-xuan/events/
    - assets/content/eras/dai-thang-mua-xuan/characters/
```

## 8. Territory atlas — `tool/geo/gen_atlas.py` (the DIVIDED map)

This is the era where the country splits. Add a `BEN_HAI = (17.0, 106.6, 107.4)`
boundary and a snapshot **after** `khang-chien`:
```python
S("khang-chien-my", "Kháng chiến chống Mỹ", "Hai miền chia cắt", 1965,
  ["dai-thang-mua-xuan"], [
    core("vndcch", "Việt Nam Dân chủ Cộng hòa", "Miền Bắc", TEAL, VN(17, 24)),
    R("vnch", "Việt Nam Cộng hoà", "Miền Nam", <PICK a distinct ochre, not TEAL>,
      "rival", VN(5, 17)),
    china("Trung Quốc"), khmer("Cao Miên", None, False), *ctx()],
  boundary=BEN_HAI,
  boundary_label="Giới tuyến quân sự tạm thời (vĩ tuyến 17)"),
```
Regen (needs the `piltmp` venv + cached `ne10m.json` — see memory
`territory-map-feature` for the exact command). Confirm snapshot count +1 and
`eras covered: 31`.

## 9. Tests — `apps/mobile/test/era_screens_test.dart`

- Add `'dai-thang-mua-xuan'` to `_DiskSource.availableSlugs()`.
- Update the count string (2 occurrences) `31 kỷ nguyên · <N> sự kiện`, where
  **N = 170 + 11 = 181**. **Recount** the total across all eras to confirm 181
  before committing.

## 10. Definition of Done (all must pass)

```bash
dart run tool/validate_content.dart      # 31 era files valid, index in sync
cd apps/mobile && flutter analyze lib     # no issues
cd apps/mobile && flutter test            # all green
```
(melos not on PATH — `dart run melos run validate:content` also works.)

## 11. Commit (only when the user asks)

Suggested split, conventional commits, on `main` (user's workflow), ending each
message with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`:
- `feat(content): Kháng chiến chống Mỹ era through 30/4/1975 (1954–1975)` — era JSON, period, people, index, atlas, pubspec, test counts.
- (only if extra app fixes arise during execution) separate `fix(...)` commits.

## 12b. App change — remove the Chào cờ calibration tool

Timings are now correct, so strip the tap-to-sync calibration from
`apps/mobile/lib/screens/chao_co/chao_co_screen.dart`: remove the header tune
toggle, the `_calib`/`_posSec`/`_caps` state, `_tapLine`/`_resetCalib`/`_capsList`,
the calibration panel widget, and the calib branch in `_onPosition` (keep the
plain highlight logic). Keep the completion-reset replay fix. Then
`flutter analyze lib` clean + `flutter test` green. Own commit:
`chore(chao-co): remove tap-to-sync calibration tool`.

## 12. Notes / gotchas

- Media (png/jpg/webp/gif/mp4/mp3…) is git-ignored — commits are code + JSON only.
- New assets need a **full rebuild** (not hot reload); the user runs Android.
- Post-1975 (reunification, Đổi Mới) is a *future* chapter — the atlas reunifies then; era 31 stays divided.
- Animated cover is opt-in via the scene `video` field (memory `static-art-default`); only add if the user provides an mp4.
