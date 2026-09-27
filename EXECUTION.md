# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: Cycle K planned, not started. Waiting on decisions K1–K4.**

## Audit of the previous plan (before adding Cycle K)

**Cycle J is fully shipped in code** (`fe6a54d`, pushed):
- Home follows the EN toggle, and the choice persists across launches
  (`FileLangStore`).
- The event list is readable: measured ~5.3–5.8:1 contrast on the brightest
  era (Gia Long).
- The Atlas is in English, with the VI→EN table in `tool/geo/atlas_i18n.py`.
- The period rail is a drag scrubber; KHÁM PHÁ moves to the next period and
  hides on the last.
- Tests: mobile 146, core_domain 35, `melos analyze` clean. Checked live in a
  Flutter web build.
- App version bumped to **1.0.2+4**.

**Still open, in the user's hands:**
1. Build and upload 1.0.2+4 to the closed-testing track
   (`flutter build appbundle --release`; the keystore stays with the user).
   - Then check on the phone: the scrubber's haptics and bubble, one-handed
     reach, and the 17 new portraits from Cycle I.
2. **Play closed test (gates production):** at least 12 testers opted in for
   14 days in a row. Aim for about 15, and ask them to actually open the app.
3. Firebase → Analytics → Custom definitions: `era_slug`, `event_id`,
   `figure_id`.
4. Deploy the privacy page. Make Play's Data safety form match
   `docs/play-store/data-safety-and-listing.md`.
5. From Cycle E: the `long_ky_tea*` products, license testing, a test
   purchase, screenshots, the feature graphic.
6. Optional: delete the unused Hosting site `admin-long-ky.web.app`.

**Known gap from J, not urgent:** the atlas English strings were patched into
the generated Dart file. The Natural Earth source and `shapely` aren't on this
machine. `gen_atlas.py` itself emits `LocalizedText` too, so a future
regeneration comes out the same.

## The feedback

> "The dry run and publish process takes around 30 minutes, which is too
> much. Can we have unsaved items state and only dry run + publish only
> those items?"

## Facts Cycle K is built on (checked, not assumed)

- **Where the time goes.** The last dry run took 18 m 55 s and the last
  publish took 11 m 8 s.

  | Step | Dry run (`36330906367`) | Publish (`36332103763`) |
  |---|---|---|
  | Runner setup (Flutter ~60 s, rclone, cwebp, `pub get`) | ~1.5 min | ~1.5 min |
  | **Pull every original** (`pull_sources.sh`: 717 files, 3.7 GB) | **9 m 46 s** | **1 m 21 s** |
  | Format, validate, `core_domain` tests | ~16 s | ~16 s |
  | **Publish step** | **6 m 51 s** | **7 m 45 s** |

  - The pull speed varies about 7× between runs (R2 throughput). It's the
    main reason timings feel unpredictable.
  - The publish step is almost all `gen_media_manifest.dart` re-encoding
    every image: "646 converted, 0 unchanged". The content pack itself and
    the `rclone sync` checks take seconds.
- **Why nothing is skipped in CI.** `gen_media_manifest.dart` already
  converts incrementally: it skips any file whose `build/media/.stamps.json`
  version matches. Each Actions runner starts empty, so the stamps never
  exist there and every run re-encodes all 646 files.
- **The gates don't need the images.** Format, `validate_content`,
  `core_domain` tests and `build_content_pack` read only the JSON. Only the
  media step needs originals on disk.
- **Every original's fingerprint is cheap to read without downloading it.**
  - `rclone lsjson r2:long-ky-sources --recursive --hash --files-only
    --no-modtime --no-mimetype --fast-list` returns all 717 files with MD5
    and size in **1.2 s**.
  - Without `--no-modtime` the same listing takes 81 s, because it fetches
    each object's metadata.
  - All 717 files have an MD5. The largest is 11 MB, so all are single-part
    uploads.
  - The bucket holds only `chao-co/` (3), `eras/` (697) and `periods/`
    (17). No `_replaced/` backups exist yet, but the CMS writes them there,
    and today's full pull would download those too.
- **The served files can also be listed cheaply.** `rclone lsf
  r2:long-ky-content/media` lists all 646 in about 1 s.
- **What "live" means today.**
  - `content/media-manifest.json` maps source path → `{key, v}`, where
    `v = md5(source bytes + "webp-q85-m6")[:10]`. Because the encoder tag is
    mixed in, `v` can't be compared to R2's plain MD5.
  - The manifest ships **inside the content pack** (`build_content_pack.dart`
    reads it). Adding fields to it changes what phones download.
  - Each real publish ends with a bot commit, "chore(content): publish
    content pack …", touching `content/content-version.json` and the
    manifest. That commit marks what's live.
- **Deletions today.** `sync_media.sh` runs `rclone sync --delete-excluded`
  **before** the new pack is uploaded. A removed image disappears from the
  CDN while phones still hold a pack that references it.
- **The CMS Publish page today** (`publish_screen.dart`):
  - Step 1 lists uncommitted edits (`draft.pendingChanges`).
  - Step 2 has Dry run and "Publish for real".
  - **Weak gate:** "Publish for real" is enabled whenever the *latest run of
    any kind* succeeded. A successful real publish from yesterday unlocks
    today's publish with no dry run of today's content.
  - It can't tell what's already live and what isn't.
  - The "Replaced" badges on media are session-only and gone on reload.
- **The Worker** (`services/cms_api`) already has what this needs: the GitHub
  token (commits, runs, dispatch) and the `long-ky-sources` R2 binding.
- **Content checks already run on commit.** `content-check.yml` runs on
  every push to `main` touching `content/**`, so a CMS commit is already
  gated before anyone presses Dry run.
- **The workflow has no `concurrency` group.** Two publishes could overlap.

## Decisions needed

- **K1 — Can the admin publish only some of the pending items?**
  *Recommend: no. Everything pending goes out together.*
  - The Publish page lists every pending item, and the dry run previews
    exactly that list.
  - Picking a subset would split the text from the media it references (an
    era pointing at a person or image that isn't live yet).
  - To hold an era back, use its existing **Draft** flag, which already
    keeps it out of the pack.
- **K2 — When a removed image leaves the CDN.** *Recommend: in the same run,
  but after the new pack is live.*
  - Today the delete happens before the new pack is uploaded, so there's a
    window where phones reference a missing image.
  - Alternative: never delete. Simple and safe, but the CDN slowly fills
    with orphans.
- **K3 — Keep a separate dry run?** *Recommend: yes, but fast and tied to
  what it previewed.*
  - Both runs become a couple of minutes.
  - "Publish" is enabled only after a successful dry run of the **same
    commit**, with no media uploaded since. This fixes today's weak gate.
  - Alternative: one run that pauses for approval (a GitHub Environment).
    The approval would happen in GitHub, not the CMS. Not recommended.
- **K4 — Keep a full rebuild?** *Recommend: yes, as an explicit "Full
  rebuild" option, never automatic.*
  - Use it for the first run that creates the ledger (K-1), an encoder
    setting change, or suspected drift.
  - It behaves exactly like today's pipeline.

## Cycle K — spec

### K-0 Confirm three small assumptions (before building on them)

1. The R2 Worker binding's `object.etag` equals the MD5 rclone reports for
   the same object, so the CMS and CI fingerprint files identically.
   - If not, the Worker returns size plus upload time, and the CMS compares
     those instead.
2. A new JSON file under `content/` is ignored by `format_content`,
   `validate_content` and `build_content_pack`, and loads harmlessly into
   the CMS draft.
   - If not, the ledger lives at `publish/media-sources.json` instead, and
     the Worker serves it.
3. `subosito/flutter-action` with `cache: true` cuts the ~60 s Flutter
   setup.

### K-1 The "what's live" ledger

- **New file:** `content/media-sources.json`, **not shipped in the pack**.
  - Contents: `{ schemaVersion, encoderTag, files: { sourcePath: { md5,
    size } } }`.
  - It records, for every served image, the exact original it was built
    from.
  - It's written by each publish and committed by the bot in the same commit
    as the manifest.
- **Bootstrap:** one Full rebuild (K4) creates it from today's state. Until
  it exists, an incremental run refuses and says to run a Full rebuild.
- `content/media-manifest.json` stays exactly as it is, so the pack and the
  phones see no change.

### K-2 Incremental publish pipeline

- **New `tool/plan_publish.dart`** writes `build/publish-plan.json` and a
  readable summary. No downloads.
  - **Text:** the `content/*.json` files changed between the last bot
    publish commit and `HEAD`.
  - **Media:** compares, in memory:
    - the referenced set from the content JSON (same walk as
      `gen_media_manifest`),
    - the ledger,
    - the source listing (the 1.2 s command above, excluding `_replaced/`),
    - the served listing of `long-ky-content/media`.

    It classifies each file as **added**, **changed** (MD5 differs),
    **removed** (no longer referenced), **missing** (referenced but not in
    sources), **drifted** (in the manifest but gone from the CDN, so it's
    rebuilt), or unchanged.
  - A full rebuild is triggered when the ledger's encoder tag differs, the
    ledger is absent, or Full rebuild is chosen.
  - **Fails the run** if any added or changed item is missing its original.
    Today that is only a warning, and it ships a broken image.
- **Download** only the added, changed and drifted originals
  (`rclone copy --files-from`). A typical change is a handful of files, not
  3.7 GB.
- **Convert** only those. `gen_media_manifest.dart` gains `--only <list>`.
  - It computes `v` for the listed files.
  - It reuses `v` from the committed manifest for everything else, so the
    manifest is still complete and identical in form.
- **Upload** only the converted files (`rclone copy --files-from`, the same
  immutable cache header).
- **Then** build and upload the pack exactly as today.
- **Then** delete the removed served keys (`rclone delete --files-from`,
  scoped to `media/`) — K2.
- **Finally** write the manifest and ledger. The bot commits both with the
  version bump.
- The dry run does everything up to and including conversion (so a bad
  image still fails it), uploads nothing, and prints the plan to the run
  summary.
- The **Full rebuild** path is today's scripts, unchanged, plus writing the
  ledger.
- The local tools stay as they are (`publish_content.sh` on the Mac).

### K-3 A faster, safer workflow

- `flutter-action` with `cache: true`.
- rclone from a pinned release binary, not the install script.
- `cwebp` installed only when the plan has something to convert.
- `concurrency: publish-content` so two publishes can never overlap.
- A `run-name` of "dry run" or "publish" or "full rebuild" plus the short
  SHA, so the CMS can tell runs apart.
- **Input `expected_sha`:** a real publish fails immediately if `main` has
  moved past the commit the dry run previewed ("content changed since the
  dry run — dry run again").
- A new `mode` input: `incremental` (default) or `full`. It replaces the
  bare `dry_run` boolean, which is kept for `gh workflow run` compatibility.

### K-4 CMS: see what's waiting, publish only that

- **New Worker endpoints:**
  - `GET /media/list`: the source listing (path, MD5, size) from the R2
    binding, excluding `_replaced/`.
  - `GET /publish/pending-text`: the `content/*.json` files changed since
    the last bot publish commit, via the GitHub compare API.
  - `GET /publish/status` gains the run's mode, head SHA and start time.
- **The Publish page is reorganised into three cards:**
  1. **Not committed yet.** Today's staged edits list, unchanged.
  2. **Waiting to publish.** Everything committed or uploaded but not live:
     - text files, shown by era or person name where possible;
     - media added, replaced or removed, with thumbnails, computed in the
       CMS from the ledger, `GET /media/list` and the existing
       `collectMediaRefs`;
     - "Nothing waiting" when it's empty, with Dry run disabled.
  3. **Dry run → Publish.**
     - Dry run is enabled when something is waiting and nothing is
       uncommitted.
     - Publish is enabled only when the latest **dry run** succeeded for the
       current `main` SHA and no media was uploaded after it started (K3).
     - A **Full rebuild** option sits behind a confirm, with a line saying
       when to use it.
- **Persistent badges:** image slots on the Era, Period, People and Media
  pages show **"Waiting to publish"** from the same comparison. It survives a
  reload, unlike today's session-only "Replaced". The session state stays
  for instant feedback before the next listing.

### K-5 Verify and ship

- **Tests:**
  - `plan_publish`, with fixtures for added, changed, removed, missing,
    drifted, an encoder-tag change and no ledger.
  - `gen_media_manifest --only` reuses unchanged versions byte-for-byte.
  - Worker endpoints (`/media/list`, `/publish/pending-text`, the status
    fields).
  - The CMS pending comparison and the Publish gate: a stale dry run, a
    different SHA, and an upload after the dry run.
  - `melos analyze` and every suite stay green.
- **Real measurement, recorded here:**
  1. A Full rebuild creates the ledger. Expect about today's time, once.
  2. A text-only change: dry run then publish.
  3. A one-image replace from the CMS: dry run then publish.

  **Target: each run ≤ 3 min** (the floor is runner setup), versus 18 + 11
  min today. The CDN listing must match the manifest after each run.
- **Browser:** Claude checks the three-card Publish page and the
  persistent badges on the deployed CMS. The final look is the user's call.
- **Deploy:** the Worker (`wrangler deploy`) and the CMS (`firebase deploy
  --only hosting:long-ky-admin`). Every real publish in this cycle happens
  only with the user's yes, as always.

### Out of scope for K

- Publishing a chosen subset of pending items (per K1). Hold eras back with
  Draft.
- Automatic publishing on commit. Publishing stays manual.
- Changing the served format or encoder settings.
- Speeding up the Mac's local `publish_content.sh`. It already converts
  incrementally.

## Next cycles (queued)

Carried-over UX audit findings (top-bar scrims, particles over text, Chào
cờ lyrics legibility, swipe-hint timing) are still parked — see
`21fb88b:EXECUTION.md`. J's scrim work may have covered "top-bar scrims";
re-check before re-proposing.
