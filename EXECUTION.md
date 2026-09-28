# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: PLANNING — Cycle L (download originals from the CMS; swap the art
of eras 36/37). Waiting on the user's answers to L1–L3.**

## Audit of the previous plan

**Cycle K is fully shipped in code** (`5a9ec5b`, `a988e2b`, `979cb3f`,
pushed; every suite green): the CMS events editor (K7), the incremental
publish pipeline (K1–K4), and Firestore as the live text layer with the
"swap only on Home" rule (K5–K6). Nothing Claude-side is left, so the Cycle K
spec is cleared from this file.

**Still open, in the user's hands** (unchanged, carried forward):
1. **Turn Firestore on** — until then the app keeps using the R2 pack, exactly
   as before. Enable Firestore → paste `firestore.rules` into its Rules tab →
   create a service account and add its key as the GitHub secret
   `FIREBASE_SERVICE_ACCOUNT_KEY` → run the one-time bootstrap
   (`cd tool && npm ci --omit=dev`, then
   `FIREBASE_SERVICE_ACCOUNT_KEY="$(cat /path/to/key.json)" node publish_firestore.mjs`).
   Full detail: `979cb3f:EXECUTION.md`.
2. **Build and upload a new app version** — bundles `cloud_firestore` and all
   the Cycle J/K app work (1.0.2+4 was never uploaded). Live updates only run
   in release builds, not `flutter run` debug builds.
3. Play closed test: 12+ testers opted in for 14 days straight (aim for ~15).
4. Firebase → Analytics → Custom definitions: `era_slug`, `event_id`,
   `figure_id`.
5. Deploy the privacy page; make Play's Data safety form match
   `docs/play-store/data-safety-and-listing.md`.
6. From Cycle E: the `long_ky_tea*` products, license testing, a test
   purchase, screenshots, the feature graphic.
7. Optional: delete the unused Hosting site `admin-long-ky.web.app`.

**Wording issue, still open:** `periods.json`'s Kỷ nguyên mới
`yearRange.display.vi` and `ky-nguyen-vuon-minh`'s `kicker.vi` still read
"2020 – now" (from the CMS edit `70b6f12`) — the Vietnamese should probably
be "2020 – nay". See L3 — Claude can fix it in the same commit as the swap.

## Cycle L — what the user asked for

1. "Add feature to download the media file. Download the image as original
   size."
2. "Swap the era image of 'Vị thế mới' and 'Kỷ nguyên vươn mình'."

### What I found

**The dialog doesn't show the original today.** The media dialog in the
screenshot (`MediaReplaceDialog`) loads its preview from the **public CDN**
(`manifest.urlFor(path)`), i.e. the *served* WebP q85. Same pixel size (the
publish step doesn't resize), but not the same file: Nhà Triệu's cover is
1086×1448 either way, but the "463 KB" in the dialog is the WebP — the real
original PNG in `long-ky-sources` is **3.0 MB**. So "download what the
preview shows" would hand back a recompressed copy, not the original.

The Worker already has an authenticated `GET /media?path=…` that streams
the original out of `long-ky-sources`, and the admin client already has
`CmsApiClient.getMedia(path)` — nothing in the UI calls it yet. That's the
right source for the download.

**The two eras' art really is crossed.** Both eras use one picture for the
cover *and* the scene sky layer (identical files, md5-verified against the
ledger):
- `vi-the-moi` (era 36, *Vị thế mới*, 2008–2019) has the **gold Nhật Tân
  bridge + fireworks** picture, but a **red** palette (`#b8322a`).
- `ky-nguyen-vuon-minh` (era 37, *Kỷ nguyên vươn mình*, 2020–2025) has the
  **sea of red flags + doves** picture, but a **gold** palette (`#e0b43c`).

Each era's palette matches the *other* era's picture, so the pictures were
most likely assigned the wrong way round when they were generated. Swapping
the pictures (and leaving the palettes alone) makes both eras consistent.
No other content references these four files.

### L-A — "Download original" in the media dialog

- A **Download original** button in `MediaReplaceDialog`, in the right-hand
  column above "Replace" (the dialog opens from every media slot in the era
  editor *and* from the Media library, so one button covers both).
- It calls `getMedia(path)` → the exact bytes in `long-ky-sources` → saves a
  file named after the path's last segment (`cover.png`, `sky.png`,
  `trieu-vu-de-lap-nam-viet.png`…). Browser download via a `Blob` + an
  `<a download>` click (`package:web`, already in the workspace lockfile;
  the admin is web-only). The Worker needs no change.
- Works for video (`.mp4`) too — same endpoint, same button.
- Shows a small spinner while fetching; a 404 (art that was never uploaded)
  or network error shows in the dialog's existing error line.
- If the image was **replaced earlier in this browser session** (not yet
  published), the download gives that new file — which is also what
  `long-ky-sources` holds now, so it's the same thing either way.
- Fix the misleading size label: the preview line becomes
  "1086×1448 · served WebP 463 KB", and once a download has run it adds
  "original 3.0 MB". (Optional — see L2.)
- Tests: a widget test that the button calls `getMedia` with the dialog's
  path and hands the bytes + filename to a swappable saver (the real saver
  is the browser-only `Blob` code, kept behind a tiny function so the test
  doesn't need a browser). Verify live in the browser pane against the real
  CMS: download Nhà Triệu's cover and confirm 3,099,232 bytes, PNG.

### L-B — swap the two eras' pictures

Swap the **bytes**, not the JSON paths — each era keeps its own
`eras/<slug>/cover.png` and `scene/sky.png`, so paths stay tidy and the
incremental publish sees exactly four changed files.

1. Back up all four current originals in `long-ky-sources` to
   `_replaced/<timestamp>/…` (the same convention the CMS's Replace already
   uses), so this is reversible.
2. Upload crosswise with `rclone copyto`: fireworks → `ky-nguyen-vuon-minh/
   {cover,scene/sky}.png`, flags → `vi-the-moi/{cover,scene/sky}.png`. Copy
   the same files into local `content/` so the Mac matches.
3. Verify: md5 of each uploaded object matches the other era's old md5.
4. `media_ledger.dart --mode incremental` must report **exactly 4 changed,
   0 added, 0 removed**.
5. Dry run (incremental) via the workflow → show the user the plan → a real
   publish **only after the user says yes**. Each served WebP gets a new
   `v`, so phones pick up the new pictures on the next media refresh; no
   app update needed.

## Decisions for the user

- **L1 — Where the download button lives.** Recommend: **in the media dialog
  only** (it opens from everywhere already). Alternative: also a download
  icon on each Media-library tile, for grabbing art without opening it.
- **L2 — Size label.** Recommend: **yes**, relabel the dialog's size line as
  "served WebP" and show the original's size after a download, so nobody
  mistakes 463 KB for the real file again. Alternative: leave the label as
  is.
- **L3 — The swap.** Recommend: **Claude does it** as above (backups first,
  then dry run, then publish only on your yes), and fixes "2020 – now" →
  "2020 – nay" in the same content commit (both `periods.json` and
  `ky-nguyen-vuon-minh`'s kicker; English stays "now"). Alternative: you do
  the swap yourself in the CMS once L-A ships — download both originals,
  then Replace each of the four slots with the other era's file.

## Next cycles (queued)

- Fold the media manifest into the Firestore live path too, so a replaced
  image's new URL also arrives without a restart (deferred from K5).
- Carried-over UX audit findings (particles over text, Chào cờ lyrics
  legibility, swipe-hint timing) are still parked — see
  `21fb88b:EXECUTION.md`. Re-check against Cycle J's scrim work before
  re-proposing.
