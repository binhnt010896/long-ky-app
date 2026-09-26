# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: Cycle H shipped — field editors, a content tree, and a real media
library are live at `https://long-ky-admin.web.app`. All of `melos
analyze`, the full test suite (Worker + every Dart package, including new
tests for the content-tree mutations and the Worker's backup-before-
overwrite), and a live browser check against the deployed CMS are clean.
The user does the first signed-in pass themselves.**

### Cycle H — what shipped, and where it was scoped down

- **H-1 content tree** (`apps/admin/lib/screens/content_tree_screen.dart`):
  periods with nested eras, add/edit/delete for both, hard-delete gated by
  typing the slug (H1), guarded against deleting a period that still has
  eras or a person still referenced by one. **Reordering is up/down
  buttons and a "move to period" menu, not drag-and-drop** — full DnD
  across a nested tree was too large for this pass; the buttons do the
  same renumbering-only-what-changed the plan called for.
- **H-2 People** (`people_screen.dart`): searchable list, a field form
  (name/epithet/bio, vi/en), the photo-fidelity checkbox as a CMS-only
  reminder, a "Used in" list, delete blocked while any era still
  references them.
- **H-3 Periods**: folded into the tree's right-hand pane
  (`_PeriodDetailPane` in `content_tree_screen.dart`) rather than a
  separate screen — title/kicker/subtitle, year range with a BCE toggle,
  accent colour with a swatch.
- **H2 draft flag**: `content/era.schema.json` gained an optional `draft`
  boolean; `tool/build_content_pack.dart` excludes draft eras (and their
  index.json entries) from the published pack, so they never reach
  installed apps over the air. **Caveat, not fixed this cycle**: a draft
  still ships in a fresh mobile *app build* (not an OTA update), since
  `apps/mobile/assets/content` is a symlink to `content/` verbatim —
  clear `draft` before cutting a release.
- **H-4 media library** (`media_library_screen.dart`): every image the
  draft actually references, grouped by period/era/person, with published
  dimensions (decoded client-side), a Missing badge for anything with no
  manifest entry (exactly the Hai Bà Trưng gap from G-2), and a replace
  flow with aspect-ratio/smaller-image/lost-transparency warnings.
  **Scoped down**: the background toggle is checkerboard/black/white/
  magenta, not "the era's real sky.png"; there's no separate "upload a
  brand-new, not-yet-referenced path" flow (still possible by pointing an
  `AssetRefField` at a period/era/person first, then replacing); and
  there's no `GET /media/exists` batch check — "Missing" means "not in
  `media-manifest.json`," which is the failure mode that actually
  occurred.
- **H3 backup-before-overwrite**: `services/cms_api/src/media.ts`'s
  `putMedia` now copies an existing object to
  `_replaced/<timestamp>/<path>` before overwriting it — best-effort (an
  admin fixing a broken image isn't blocked by a failed backup write).
  Two new Worker tests cover it.
- **Sync hazard fix**: `tool/push_sources.sh` now runs `rclone copy
  --update`, so a stale local file can no longer silently overwrite a
  newer CMS-uploaded original. (`pull_sources.sh` needed no change — cloud
  is already always authoritative in that direction.)
- **R2 CORS**: the user added a CORS policy to `long-ky-content` scoped to
  `https://long-ky-admin.web.app` (not `localhost`) — confirmed live with
  a `curl` preflight check. Media features are therefore verified against
  the deployed CMS, not local dev.
- **Shared widgets added**: `LocalizedTextField`, `YearRangeField`,
  `HexColorField`, `CitationField`, `AssetRefField` — used across the era
  editor, the tree's period pane, and the people screen.

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
