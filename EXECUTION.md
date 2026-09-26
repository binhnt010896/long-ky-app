# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: PLANNING Cycle H (CMS v2 — field editors, a content tree, a real
media library). Nothing built yet. Three decisions (H1–H3) and one
pre-flight action need the user before execution.**

## Where things stand

- **Cycle F** (Firebase Analytics + Crashlytics) — shipped. Detail:
  `ab81eb4`.
- **Cycle G** (the CMS) — shipped and live:
  - CMS: `https://long-ky-admin.web.app`, Flutter web in `apps/admin`.
  - Worker: `https://long-ky-cms-api.binhnt-010896.workers.dev`
    (`services/cms_api`).
  - Originals live in private R2 `long-ky-sources`; publishing runs in
    GitHub Actions (`publish-content.yml`).
  - Full G notes: `d64c738:EXECUTION.md`.
  - Post-launch fixes (`26c647d`): the Worker decoded content as Latin-1, so
    every Vietnamese diacritic came through as mojibake. It now decodes
    UTF-8, with a test; no bad commit ever landed. Sign-in now goes through
    Firebase's own popup. The Hán-tự placeholder logo was replaced with the
    Long Ký seal.
- **What Cycle H replaces**: G-4 shipped People/Periods as whole-file raw
  JSON, a flat era list, and a Media screen where you type a path by hand.
  Cycle H is the user's three asks:
  1. Field-by-field People and Periods editors.
  2. A Periods → Eras tree with add, edit, remove and reorder.
  3. A media library showing the real current images with their
     dimensions, plus replace-in-place.

## Facts the plan is built on (checked, not assumed)

- **People**: 154 people in one `content/people.json`. Schema: `id`, `name`
  (required), `epithet`, `bio` (each `{vi, en}`, `vi` required), and the
  asset refs `portrait`, `avatar`, `fullBody`. Eras point at people via
  `characters[].ref`, and `events[].figureIds` must be in the era's roster.
- **Periods**: 17 periods in one `content/periods.json`.
  - Required: `id`, `order`, `title`, `kicker`, `yearRange`, `accent`.
  - Optional: `subtitle`, `cover`.
  - `yearRange` = `{display{vi,en}, startYear, endYear}`; negative years
    are BCE.
- **Eras**: 38 era files. Each has `period` (the parent) and a global
  integer `order`; the app sorts by `order`. `id == slug` for every era.
  `index.json` must list exactly the era files. Required: `schemaVersion`,
  `id`, `slug`, `order`, `period`, `title`, `kicker`, `subtitle`,
  `yearRange`, `palette.accent`, `primarySource`, and `events` (at least 1,
  each with a `citation`).
- **Media**:
  - An asset ref's `flagship`/`reduced`/`placeholder` is a source path,
    e.g. `eras/au-lac/characters/cao-lo.png`.
  - `media-manifest.json` maps each source path to `{key, v}`.
  - The CDN serves `…r2.dev/media/<key>?v=<v>`.
  - **Publish converts to WebP (q85) but never resizes**, so the CDN copy's
    pixel size is the original's. Dimensions can come from the fast WebP;
    there's no need to pull 5 MB PNGs.
- **CDN CORS — blocker**: `GET …r2.dev/media/…` with `Origin:
  https://long-ky-admin.web.app` returns 200 but **no
  `Access-Control-Allow-Origin`**. Flutter web can't load cross-origin
  images without it, so the media library can't show a single thumbnail
  until this is fixed. See pre-flight below.
- **Sync hazard found while planning**: `push_sources.sh`/`pull_sources.sh`
  use plain `rclone copy`, which overwrites whenever size or modtime
  differ.
  - Once the CMS can replace an image in `long-ky-sources`, the next
    `push_sources.sh` from the Mac would quietly put the **old** local file
    back.
  - Must fix before replace-in-place ships (H-4).

## Decisions needed

- **H1 — Removing an era.** *Recommend: hard delete.* It removes the JSON
  and its `index.json` entry in one commit. You confirm by typing the slug.
  Undo is `git revert`, and the originals stay in `long-ky-sources`. The
  next publish drops its served files from the CDN. (The alternative, a
  "hidden" flag, is a schema change for little gain.)
- **H2 — Half-written new eras.** A new era is authored over days, but
  anything in `index.json` ships on the **next publish**, including a
  publish made only to fix a typo elsewhere.
  - *Recommend:* add an optional `"draft": true` to the era schema.
    `build_content_pack.dart` and the media manifest skip drafts, so
    **installed apps never receive them**, old app versions included. The
    CMS shows a DRAFT badge and a "Mark ready" button.
  - Alternative: no draft state. A new era must be complete (at least one
    cited event) before it's created, and it goes live on the next publish.
- **H3 — Replacing an image overwrites its original**, and
  `long-ky-sources` has no versioning.
  - *Recommend:* before overwriting, the Worker copies the old original to
    `_replaced/<timestamp>/<path>` in the same bucket. It's cheap, needs no
    UI, and you can recover by hand.
  - Alternative: overwrite with no backup (the Mac may still hold a copy,
    but not for CMS-only uploads).

## Pre-flight — the user's hands (about 1 minute, before H-4)

Cloudflare dashboard → R2 → `long-ky-content` → Settings → **CORS policy**
→ add:

```json
[{ "AllowedOrigins": ["https://long-ky-admin.web.app", "http://localhost:3020"],
   "AllowedMethods": ["GET", "HEAD"], "AllowedHeaders": ["*"], "MaxAgeSeconds": 86400 }]
```

It's read-only and limited to the CMS's origins; the mobile app is
unaffected (native apps don't use CORS). Claude verifies it afterwards with
the same `curl` check. Fallback if you'd rather not: the Worker proxies
thumbnails. That works, but every image then goes through the Worker.

## Cycle H — spec

### Principles (all stages)

- **Edit maps, not models.** Forms read and write the raw decoded JSON map
  of each item, so any key a form doesn't know about survives a save. The
  "Raw JSON" tab stays on every item as the escape hatch.
- **IDs are locked once created.** This covers era slug/id, period id and
  person id. They're baked into media paths, the analytics `era_slug`, and
  the refs in other files. The id field is editable only while creating.
- **Everything is still gated by `ContentValidator`.** Forms add friendlier,
  earlier checks (required fields, a citation on events), but the validator
  stays the real gate. Commit remains blocked while any issue exists.
- **Referential safety in the UI.**
  - You can't delete a person any era still references; the UI lists
    those eras instead.
  - You can't delete a period that still has eras; move or delete them
    first.
  - The validator would catch both anyway; the UI just explains why.

### H-0 Foundations (`apps/admin`)

- **`ContentDraft` supports adding and deleting files.**
  - `pendingChanges` becomes `Map<String, String?>`: new paths are
    included, deleted paths map to `null`. The Worker's `/commit` already
    accepts both.
  - The dashboard and Publish pages list changes as added / edited /
    deleted.
- **Shared form widgets:**
  - `LocalizedTextField`: a vi/en pair; vi is required, matching the
    schema.
  - `YearRangeField`: display vi/en plus start/end years, with a BCE
    toggle instead of typing negative numbers.
  - `HexColorField`: a swatch plus a hex input.
  - `AssetRefField`: shows the thumbnail and path, with "Replace…" opening
    the media detail (H-4).
- **Unsaved-changes guard**: leaving an item with unstaged edits asks
  first.

### H-1 Content tree (replaces the flat Eras list)

- A left-hand tree: **periods in `order`, with their eras nested in era
  `order`**. Each row shows the title, year range, and a status (issue
  count, DRAFT if H2 goes that way).
- Selecting a row opens its editor on the right. A period opens H-3; an era
  opens the existing era editor (guided + raw).
- **Add**
  - "+ Period": a form with the required fields; the id is suggested from
    the title with diacritics stripped (`Hồng Bàng` → `hong-bang`).
  - "+ Era in this period": a minimal form (slug, title, kicker, subtitle,
    yearRange, accent, primarySource, a first event with citation). It
    creates `content/eras/<slug>.json` plus the `index.json` entry.
- **Remove**, per H1: typed-slug confirmation for eras; periods only when
  empty.
- **Reorder / move**
  - Drag within a period to reorder; drag an era onto another period to
    move it (this rewrites its `period`).
  - Era `order` is renumbered 0…n-1 in tree order, but only files whose
    number actually changed are written, so a reorder never touches more
    than it must.
  - Period `order` works the same way inside `periods.json`.
  - `index.json` is rewritten in the same order.

### H-2 People editor

- A searchable list of 154 people (name vi/en, id). Filter chips: "has
  portrait", "unused" (referenced by no era).
- The person form:
  - Name, epithet and bio (vi/en; bio multi-line).
  - `portrait`/`avatar`/`fullBody` shown as thumbnails via `AssetRefField`.
  - A **"Used in"** list of the eras whose roster includes them (links),
    shown read-only.
- The photo-fidelity checkbox moves into this form. It shows on any person
  with an image and stays CMS-only, never written to the file
  ([[camera-photo-fidelity]]).
- Add person (id suggested from the name, locked after creation). Delete
  is only allowed when "Used in" is empty.

### H-3 Periods editor

A field form opened from the tree: title/kicker/subtitle (vi/en),
`yearRange`, `accent` (with a swatch preview), and `cover` (thumbnail).
Order comes from the tree; the id is locked.

### H-4 Media library (replaces the path-typing Media screen)

**Browse**
- The library is built from what the content actually references: it walks
  the draft's era/people/period JSON for every asset path.
- Groups: Periods (covers) · each era (cover, scene layers, per-era
  character art, event heroes) · People (portrait/avatar/fullBody).
- Each tile:
  - A thumbnail from the CDN (`media/<key>?v=<v>`) and its **pixel
    dimensions**, decoded in the browser.
  - The served file size, from `Content-Length`.
  - Which items use it.
- Tile states:
  - **Published**: in the manifest.
  - **Missing**: referenced but in neither the manifest nor
    `long-ky-sources`. This is exactly the Hai Bà Trưng ridge-art case from
    G-2, now caught at a glance.
  - **Replaced, publish to go live**: uploaded this session.

**Detail view**
- A large preview with zoom, and a **background toggle**
  (checkerboard / magenta / the era's real `sky.png`). This is the same
  transparency check done by hand for generated art.
- Original path, dimensions, whether it has alpha, and "used by" links.

**Replace**
1. Pick a file. It must be the same file type as the path; a `.png` path
   takes a PNG.
2. See old and new side by side, with dimensions.
3. **Warnings** (not blocks):
   - The aspect ratio differs from the current image by more than 1%.
   - The current image has transparency and the new one doesn't (a
     scene-layer killer).
   - The new image is smaller than the current one.
4. Confirm → the Worker backs up the old original (H3) → `PUT` to the same
   path.
5. Nothing in the JSON changes. The next publish re-converts it, bumps
   `v`, and the app refetches.

**Worker**
- `PUT /media` gains the H3 backup copy.
- New `GET /media/exists?paths=` (batched `head()`) so "Missing" is
  accurate for paths not yet published.

**Sync fix**
- `push_sources.sh`/`pull_sources.sh` gain `rclone --update` (never
  overwrite a newer file).
- `push_sources.sh --check` failing now tells you to run
  `pull_sources.sh` first, not to push.
- This is the hazard noted above.

**Uploading new media** (a path not yet referenced) stays available as an
"Upload new…" action in the library, with a folder picker built from
existing folders instead of free typing.

### H-5 Verify and ship

- **Tests**
  - `ContentDraft` add/delete/pending diff.
  - Tree reorder: only the changed `order`s get written, and `index.json`
    stays in sync.
  - Every form round-trips unknown keys untouched.
  - Delete guards.
  - Worker: backup-then-overwrite, `exists`.
  - `melos analyze` and the full test suites stay green.
- **Browser**: local run against the live Worker for every screen. The
  user does the signed-in pass (Claude can't sign in as them).
- **Deploy**: Worker redeploy plus `firebase deploy --only
  hosting:long-ky-admin`, **each with the user's explicit yes**.

### Out of scope for H (noted, not planned)

- Per-event field editor (events stay in the era editor's Raw JSON).
- A pixel-exact preview using the real app screens (G-4's scope cut
  stands).
- An image cropper or resizer in the browser.

## Paused — needs the user's own hands

1. Firebase console → Analytics → Custom definitions: register
   event-scoped dimensions `era_slug`, `event_id`, `figure_id` once real
   data arrives.
2. Re-paste the updated privacy policy at binh-nt.dev (the portfolio page
   is built; `firebase deploy` it). Make the Play Console Data safety form
   match `docs/play-store/data-safety-and-listing.md` **before** uploading
   1.0.1+3.
3. Upload the 1.0.1+3 `.aab` to a release.
4. From Cycle E: payments profile verification, create and activate the
   `long_ky_tea*` products, license testing, a real test purchase,
   screenshots and the feature graphic.
5. Optional: delete the unused Hosting site `admin-long-ky.web.app`.

## Next cycles (queued)

Carried-over UX audit findings (top-bar scrims, particles over text, Chào
cờ lyrics legibility, swipe-hint timing) are still parked — see
`21fb88b:EXECUTION.md`.
