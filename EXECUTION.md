# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: Cycle N is built, tested and pushed on branch `m-cycle` (with Cycle
M). Nothing from M or N is on `main`, published, or in a build yet. What is
left needs the user, in a fixed order — see "What's left, in order" below.
The Worker's new content loader (N step 1) is already deployed.**

Cycle N's spec, with its decisions (N-D1–N-D3, N1–N7), is at
`92e699f:EXECUTION.md`.

## What shipped in Cycle N

**Step 1 — the CMS content load (deployed).** The Worker is on Workers Free
(50 subrequests per request); the old loader spent one per content file plus
three. Now it spends **2–3, however many files there are**: the head sha, one
GraphQL query pinned to that exact commit (so the files and the sha can't
disagree), and a REST blob read only for files GraphQL truncates.
- **Spike finding that changed the plan:** GraphQL truncates a blob's text
  somewhere below ~790 KB (a 787,843-byte file came back `isTruncated`; a 305
  KB one didn't). `events.json` is 1.1 MB, so it *is* truncated — the plan's
  tarball fallback wasn't needed; a per-file REST read for just the truncated
  ones is cheaper.
- Verified on the real repo: 47 files in 2 subrequests, byte-identical to git.
  Worker deployed as version `3626c306`. Commit `6962901`.

**N-A/B — the registry and the migration** (`1204260`). `content/events.json`
(237 events), `event.schema.json`, eras list `{"ref": id}` with list position as
the order. `tool/migrate_events.dart` moved all 237 out of the 38 eras and
verified every era re-inlines to its original **value for value** (37 of 38
byte-identical; the one exception is the era whose events had an unusual key
order — same data). A second run is a no-op.
- Validator: registry schema; unknown, duplicate and twice-listed refs; an event
  in at most one era; related events across eras and standalone; a standalone
  event needs a dated year, a hero, and figures on some era's roster.

**N-C — publishing** (`2a5bc3f`). Packs, Firestore and the media tools follow
the registry. The pack keeps every era's events **inlined with `order`** and
adds an optional `standaloneEvents` key, so **every installed app build still
parses it** — proved by parsing a real built pack with the pre-Cycle-N parser
(38 eras, 237 events, same 1,304 KB). The media tools read `events.json`
(without that, every event hero looks unreferenced and an incremental publish
would delete them — the CI dry run confirms `0 to remove`).

**N-D — the app** (`954c092`, `9dcf931`). `/su-kien/:id` (an event in an era
redirects to its era route *before* telemetry sees a location; a standalone one
opens its own page), global-timeline nodes marked "Sự kiện riêng" and placed per
N6, quiz, "Cũng xuất hiện trong" on the Character page, street targets.

**N-E — the CMS** (`93e4480`). A new Events screen, the era editor's "Add
existing event" / "Remove from era", standalone mode in the event dialog
(including creating a hero slot — previously an event without a hero had no way
to get one), cross-era related events with search, and deletes that clean the
era, every related link and every street that names the event.

### Bugs found and fixed along the way
- **The running app never loaded `events.json`** (`9dcf931`). `main.dart` built
  its own bundled source without the new path; every test swaps in a disk
  source, so all were green while every era would have failed on a phone.
  Found only by a real browser build. Now one shared `appBundledContent()`, and
  a test loads the real wiring through the real asset bundle (verified to fail
  when the path is dropped).
- `publish_firestore.mjs` read `content/…` relative to the working directory,
  but CI and the bootstrap instructions run it from `tool/` — it would have
  crashed the first time a key existed (a Cycle K bug). Fixed; `--dry-run` no
  longer needs credentials.
- The CMS event dialog's Kind dropdown overflowed its width, and the typed-
  confirm delete dialogs disposed their text controller while still animating
  (both latent; found by the new widget tests).

### Verified
core_domain 93, core_content 28, mobile 187, admin 55, Worker 30, JS 6;
`melos analyze` clean; content formatted and valid (51 files). A real browser
build of the app: `/su-kien/trieu-vu-de-lap-nam-viet` redirects to its era
route, the event renders in full, the timeline shows "38 eras · 237 events".
CMS flows are tested over the **real content with the real validator after every
step** (create standalone → move into an era → out → delete). A CI dry run of
the branch passes every check up to the media plan; its one failure is the
Cycle M geometry upload below.

**Not verified:** the CMS screens in a real browser (they sit behind your Google
sign-in), and the Worker loader against production's own GitHub token — only
against the same repo through your `gh` login.

## What's left, in order

1. **Open the CMS and confirm it loads.** The new loader is live; if it fails
   to load (most likely cause: the Worker's token can't use GraphQL), roll back
   and tell me:
   ```bash
   cd services/cms_api && npx wrangler rollback
   ```
2. **Upload the street geometry** (Cycle M's step): `tool/push_sources.sh`. The
   CI dry run fails at the media plan without it (`streets/hcm-streets.geojson`
   is referenced but not in `long-ky-sources`).
3. **Merge `m-cycle` into `main`** (Cycle M + N together), **then deploy the
   CMS immediately after.** Between the merge and the deploy the *currently
   deployed* CMS can't read the migrated content (events are refs now), so keep
   that gap to minutes and don't edit in the old CMS after the merge. Order
   matters: never merge before step 1 is confirmed.
4. **Publish:** dry run → your yes → real publish. Installed apps are
   unaffected (same pack shape); Firestore skips itself until set up.
5. **Firestore** (still not turned on): the steps are in `979cb3f:EXECUTION.md`.
   Two additions from this cycle: paste the updated `firestore.rules` (it now
   allows public read of `events/`), and run the bootstrap **from `tool/`** as
   written there — it works from there now.
6. **A new app build** for Cycles M and N (standalone events, the street map).
   Hold the Sảnh street entry back until `hcm-streets.geojson` and the basemap
   are in place (Cycle M's open items: PMTiles extract and its R2 upload).

**Still open from before** (unchanged): the Play closed test (12+ testers
opted in for 14 days; the last build is `1.0.3+6`), Firebase Analytics custom
definitions (`era_slug`, `event_id`, `figure_id`), the privacy page and Data
safety form, Cycle E's tea products / license testing / screenshots / feature
graphic, and optionally deleting the unused Hosting site
`admin-long-ky.web.app`.

## Next cycles (queued)

- **Write the first standalone events** in the CMS — the machinery is done; no
  real standalone event exists yet (the app's tests use a fixture).
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
