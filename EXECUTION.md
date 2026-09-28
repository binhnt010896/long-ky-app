# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: Cycle K planned, not started.**
- K1–K4 are confirmed as recommended: publish everything waiting, delete
  removed images after the pack is live, keep a fast dry run tied to its
  commit, and keep a manual Full rebuild.
- **Waiting on K5–K7.**

## Audit of the previous plan (before adding to Cycle K)

**Cycle J is fully shipped in code** (`fe6a54d`, pushed):
- Home follows the EN toggle, and the choice persists.
- The event list is readable (~5.3–5.8:1 contrast).
- The Atlas is in English.
- The period rail is a drag scrubber; KHÁM PHÁ moves to the next period.
- Tests: mobile 146, core_domain 35. App version **1.0.2+4**.

**The user has since run a CMS edit, a dry run and a publish.** All three
succeeded:
- The CMS commit is `70b6f12`.
- Runs `36367460228` (dry run) and `36368513220` (publish).
- The bot commit is `b86208a`, pack `20260928021659`.
- **The app didn't show the change.** The cause is in the facts below, and
  the fix is K-6.

**Still open, in the user's hands:**
1. Build and upload the app to the closed-testing track. See the build note
   in K-6: ideally ship K-6 in the same build.
   - Then check on the phone: the scrubber, and the 17 new portraits.
2. **Play closed test (gates production):** at least 12 testers opted in for
   14 days in a row. Aim for about 15, and ask them to actually open the app.
3. Firebase → Analytics → Custom definitions: `era_slug`, `event_id`,
   `figure_id`.
4. Deploy the privacy page. Make Play's Data safety form match
   `docs/play-store/data-safety-and-listing.md`.
5. From Cycle E: the `long_ky_tea*` products, license testing, a test
   purchase, screenshots, the feature graphic.
6. Optional: delete the unused Hosting site `admin-long-ky.web.app`.
7. **New, a content wording check on the user's own edit (`70b6f12`):** the
   Vietnamese fields now say **"now"** in English:
   - `periods.json`, Kỷ nguyên mới, `yearRange.display.vi`: "2020 – now".
   - `ky-nguyen-vuon-minh`, `kicker.vi`: "(2020 – now)".

   The Vietnamese is probably meant to be **"nay"** ("2020 – nay"). The user
   decides, and fixes it in the CMS.

## The feedback

1. "Publish" ran, but the change doesn't show in the app. *(Diagnosis
   below.)*
2. The dry run plus publish takes ~30 min. Publish only what's waiting.
   *(K-0…K-5, planned last round.)*
3. Would **Firebase Firestore** be faster? Last time it updated almost
   instantly. *(K5.)*
4. Add **events** create/edit/delete to the CMS. *(K-7.)*

## Facts Cycle K is built on (checked, not assumed)

### Why the published change didn't show (feedback 1)

- **The server side is correct.**
  - `latest.json` on the CDN points at pack `20260928021659` (served with
    `Cache-Control: no-cache`).
  - The pack's sha256 matches.
  - The pack contains the edit ("2020 – now").
- **The app only looks for new content at a cold start**, in the splash
  (`SplashGate._run`).
  - There is **no check when the app comes back to the foreground** (no
    lifecycle hook anywhere in `apps/mobile/lib`). Reopening it from Recents
    never checks.
- **The splash gives the check 2 s**, and that covers both `latest.json` and
  the whole pack.
  - The pack is **1.5 MB, served uncompressed**: `Content-Length: 1506197`,
    no `Content-Encoding`. The `r2.dev` URL doesn't compress.
  - From this Mac on broadband the two requests take 1.24 s. On a phone they
    often won't fit in 2 s.
  - When they don't fit, the download finishes in the background and is
    saved, but it's **only adopted at the *next* cold start**.
- **So today a change takes two full restarts to appear.** Reopening from
  Recents does nothing.
- **Workaround the user can do now, no build needed:**
  1. Swipe Long Ký away in Recents.
  2. Open it and wait a few seconds on Home.
  3. Swipe it away again.
  4. Open it again.

### Speed of the publish pipeline (feedback 2, from last round, unchanged)

- The last dry run took 18 m 55 s and the last publish 11 m 8 s.
- Almost all of it is re-downloading every original (3.7 GB, 1–10 min) and
  re-encoding all 646 images (~7 min).
- Every runner starts empty, so the existing incremental stamps
  (`build/media/.stamps.json`) never help.
- A fingerprinted listing of all 717 originals (`rclone lsjson … --hash
  --no-modtime --no-mimetype --fast-list`) takes **1.2 s**, with an MD5 for
  every file.
- Listing the 646 served files takes ~1 s.
- The media manifest ships **inside** the pack, so the "what's live" ledger
  must be a separate file.
- `sync_media.sh` deletes removed images **before** the new pack is live.
- The CMS's "Publish for real" unlocks after *any* successful run, not a dry
  run of the current commit.
- The workflow has no `concurrency` group.

### Firestore compared (feedback 3)

|  | Today | After K + K-6 | Firestore |
|---|---|---|---|
| Text edit → live on the server | dry run + publish ≈ 30 min | ≈ 2–3 min per run | seconds |
| Image edit → live | same ≈ 30 min | ≈ 2–3 min | not faster: images still need converting and a CDN (Firestore doesn't hold images) |
| When a phone sees it | 2 cold starts | next time the app is opened or brought back | instantly, if the app keeps a live listener open |
| Check before it goes live (schema, references, tests, dry run) | yes | yes | **no**: a typo or wrong date reaches every phone immediately |
| History and rollback | every edit is a Git commit; any pack can be republished | same | none built in |
| Work to switch | — | — | rewrite the content layer and the CMS; migrate 38 eras, 237 events, the people and periods; rebuild offline and first-launch content |
| Running cost | CDN egress only | same | billed per document read; every phone reading every era adds up |

- The "almost instant" feel came from a live listener: a write reaches
  connected phones in about a second.
- That speed exists because nothing checks the write. For a history app with
  a sourcing standard ([[stay-close-to-dvsktt]],
  [[modern-era-sourcing-gov-pov]]), that check is worth keeping.

### Events today (feedback 4)

- **237 events** across the eras, edited **only as raw JSON** in the CMS.
  The Images tab already covers each event's hero image.
- **Fields** (`historyEvent` in `era.schema.json`):
  - Required: `id`, `order`, `kind` (legend / semi-historical /
    historical), `year` (`display` vi/en, `value` integer or null,
    `approximate`), `title`, `summary`, `citation`.
  - Optional: `slug`, `body`, `details`, `pullQuote` (`text` and
    `attribution`), `hero`, `figureIds`, `relatedEventIds`.
  - Every existing event has `slug`, `body` and `hero`.
- **Rules the data follows today, though the validator only checks the
  last one:**
  - `id == slug` for all 237.
  - Event ids are **unique across all eras**.
  - Each era's `order` runs 0…n−1 with no gaps.
  - Every `relatedEventIds` entry resolves.
  - `figureIds` must be in the era's `characters` roster (**this one is
    validated**).
- **An event id is public.** It appears in app links
  (`/era/<slug>/event/<id>`), quiz questions (`eventId`) and analytics
  (`event_id`). Renaming a published one breaks all three.
- **Hero path convention:** `eras/<era>/events/<id>.png` (229 of 237).
- The era's **character roster** (`characters`) is also raw-JSON-only
  today.

## Decisions needed

- **K5 — Move content to Firestore?** *Recommend: no.*
  - Keep the Git-backed, validated pack, and make it fast: K brings each run
    to ~2–3 min, and K-6 makes phones pick changes up the next time the app
    is opened or brought back.
  - Firestore would make **text** edits reach phones in seconds, but images
    wouldn't be faster. It would also remove the check before content goes
    live, lose edit history, need a rewrite, and bill per read.
- **K6 — When a phone switches to new content mid-session.** *Recommend:*
  - Check at launch, as today, and also whenever the app comes back to the
    foreground (at most every 10 min).
  - Switch to the new pack immediately if the reader is on Home. Otherwise
    switch the next time they return to Home.
  - No banner, no "update available" prompt ([[delicate-ui-no-nags]]).
  - Alternative: switch immediately wherever they are. Simpler, but the text
    could change under someone mid-read.
- **K7 — Events editor rules.** *Recommend:*
  - A new event's **id is generated from its title** and editable **until
    its first publish**. After that it's read-only, with a note: "used in app
    links, the quiz and analytics".
  - **Picking a person** for an event may choose anyone from People. If they
    aren't in this era's roster yet, they're **added to the roster
    automatically** (a plain `{ "ref": id }`, no per-era overrides).
    Per-era name/epithet overrides and removing roster entries stay in Raw
    JSON.
  - **Deleting an event** also removes it from other events' "Related"
    lists and closes the gap in `order`, after a typed-id confirm that lists
    those references.
  - **Moving an event to another era** is out of scope.

## Cycle K — spec

K-0…K-5 are unchanged from last round, with K1–K4 now confirmed. K-6 and K-7
are new.

### K-0 Confirm the small assumptions (before building on them)

1. The R2 Worker binding's `object.etag` equals rclone's MD5 for the same
   object. If not, the CMS compares size plus upload time instead.
2. A new `content/media-sources.json` is ignored by `format_content`,
   `validate_content` and `build_content_pack`, and loads harmlessly into
   the CMS draft. If not, it moves to `publish/`.
3. `flutter-action` with `cache: true` cuts the ~60 s Flutter setup.
4. **(For K-6)** A pack uploaded gzip-compressed (`Content-Encoding: gzip`)
   works for the **already-installed** app versions.
   - `package:http` on Android decompresses transparently, and the sha256
     stays over the uncompressed JSON.
   - Test against a real gzipped object on the CDN before switching the
     publish over.

### K-1 The "what's live" ledger

- `content/media-sources.json`, not shipped in the pack:
  `{ schemaVersion, encoderTag, files: { sourcePath: { md5, size } } }`.
- It's written by each publish and committed by the bot with the manifest.
- **Bootstrap:** a Full rebuild creates it. Until then an incremental run
  refuses and says to run a Full rebuild.
- `media-manifest.json` is unchanged.

### K-2 Incremental publish pipeline

- **`tool/plan_publish.dart`** writes `build/publish-plan.json` plus a
  readable summary, with no downloads:
  - **Text:** the `content/*.json` files changed since the last bot publish
    commit.
  - **Media:** compares the referenced set, the ledger, the source listing
    (excluding `_replaced/`) and the served listing. Each file is added,
    changed, removed, missing, drifted (in the manifest but gone from the
    CDN) or unchanged.
  - **Full rebuild** if the ledger is absent, its encoder tag differs, or
    it's chosen.
  - **Fails** if an added or changed item has no original.
- **Download** only added, changed and drifted originals.
- **Convert** only those (`gen_media_manifest.dart --only`), reusing `v` for
  everything else.
- **Upload** only those.
- **Then** build and upload the pack. It's **gzip-compressed** once K-0.4
  passes.
- **Then** delete removed served keys (K2).
- **Then** write the manifest and ledger. The bot commits both.
- **The dry run** does everything up to and including conversion, uploads
  nothing, and prints the plan to the run summary.
- **Full rebuild** is today's scripts plus writing the ledger.
- The Mac's local tools are unchanged.

### K-3 Faster, safer workflow

- `flutter-action` with `cache: true`.
- A pinned rclone binary.
- `cwebp` installed only when something needs converting.
- `concurrency: publish-content`.
- `run-name` = mode plus the short SHA.
- **`expected_sha`:** a real publish fails if `main` moved since the dry
  run.
- A `mode` input: `incremental` (default) or `full`. `dry_run` is kept.

### K-4 CMS: see what's waiting, publish only that

- **Worker endpoints:**
  - `GET /media/list` (the source listing).
  - `GET /publish/pending-text` (the GitHub compare API from the last bot
    publish commit).
  - `GET /publish/status` gains mode, head SHA and start time.
- **Publish page, three cards:**
  1. **Not committed yet.**
  2. **Waiting to publish:** text by era or person name, plus media added,
     replaced or removed with thumbnails. "Nothing waiting" disables Dry
     run.
  3. **Dry run → Publish.**
     - Publish is enabled only after a successful **dry run** of the current
       `main` SHA with no uploads since.
     - **Full rebuild** sits behind a confirm.
- **Persistent "Waiting to publish" badges** on image slots (Era, Period,
  People, Media), from the same comparison.

### K-5 Verify the pipeline

- **Tests:**
  - `plan_publish`, with fixtures for added, changed, removed, missing,
    drifted, an encoder-tag change and no ledger.
  - `gen_media_manifest --only`.
  - The Worker endpoints.
  - The CMS pending comparison and the Publish gate.
- **Real measurement, recorded here:**
  1. A Full rebuild creates the ledger.
  2. A text-only change: dry run plus publish.
  3. A one-image replace: dry run plus publish.

  **Target: each run ≤ 3 min.** The CDN must match the manifest after each.
- Every real publish happens only with the user's yes.

### K-6 Phones pick up new content quickly (feedback 1, K6)

- **Check when the app comes back to the foreground.** An
  `AppLifecycleListener` watches for `resumed`, rate-limited to once every
  10 min, in addition to today's splash check. The download runs in the
  background as today.
- **Adopt per K6:**
  - If the reader is on Home (route `/`) when a verified pack lands, swap it
    in at once. This is the same swap as the splash, `_activatePack`, moved
    somewhere both can use it.
  - Otherwise mark it pending and swap on the next return to Home.
  - No UI announcement.
- **Smaller download:** the gzip pack (K-2, after K-0.4) is roughly
  1.5 MB → ~0.2 MB (measured when built), so the 2 s splash check usually
  finishes and adopts on the first launch.
  - The splash budget stays 2 s. The splash must not get slower.
- **Tests:**
  - A resume triggers a check, and is rate-limited.
  - A pack arriving off Home is adopted only on returning to Home.
  - A pack arriving on Home is adopted at once.
  - The gzip response decodes and its hash verifies.
- **Build note:** this is app code, so it ships in a new build.
  - If 1.0.2+4 **hasn't been uploaded yet**, build K-6 first and upload once.
  - Otherwise it goes out as **1.0.3+5**.
  - K-6 is independent of K-1…K-4, so it can go first.
- **Honest limit:** phones only update when the app is opened or brought
  back. A phone sitting unused won't change until then.

### K-7 Events editor in the CMS (feedback 4, K7)

- **An "Events" tab on the Era page**, next to Guided, Images and Raw JSON.
- **The list:** events in order, each with its year display, title, a kind
  chip and a hero thumbnail.
  - Up/down reorder, which rewrites `order` as 0…n−1.
  - Search.
  - **Add event:** a new event at the end, pre-filled so it validates:
    - kind "historical";
    - year display copied from the era's range;
    - the era's primary source as the citation;
    - a placeholder title and summary;
    - the hero at the conventional path, flagged "no image yet" until
      uploaded.
- **The event form:**
  - Title, Summary (one line), Body, and Details ("read more"), each in
    Vietnamese and English.
  - **Kind**, with a short explanation of each option.
  - **Year:** a numeric value (negative = TCN/BCE, empty = undated legend)
    and an "approximate" checkbox.
    - The **display text is suggested** from those (e.g. "≈ 2879 TCN" /
      "≈ 2879 BCE"), and can be edited.
  - **Citation** (the existing `CitationField`).
  - **Pull quote:** text and attribution, optional.
  - **Figures:** a people picker (per K7) that auto-adds anyone missing to
    the roster.
  - **Related events:** a picker over the other events in this era.
  - **Hero image:** the existing `MediaSlot`, with Add or Replace.
  - **Id:** generated and editable until first published, then locked
    (K7).
- **Delete:** a typed-id confirm listing the references it will clean (K7).
- **Controller** (`content_draft.dart`): `addEvent`, `updateEvent`,
  `deleteEvent`, `reorderEvent`, plus a helper to add a person to the
  roster. Each is a normal staged change: commit, then publish.
- **Validator additions** (`core_domain`, so CI, the publish gates and the
  CMS Commit button all enforce them):
  - `id == slug`;
  - event ids unique across all eras;
  - `order` contiguous from 0;
  - `relatedEventIds` resolve within the era and never point to the event
    itself.

  All 237 existing events already pass these (checked above).
- **Tests:**
  - Each controller method: add produces a valid event; update; delete
    cleans related lists and re-compacts order; reorder; auto-adding to the
    roster.
  - The id lock after publish.
  - Each new validator rule, a failing case each.
  - The whole real content set still validates clean.

### K-8 Deploy and order

- **Suggested order:**
  1. K-6 (app pickup, small, unblocks seeing edits).
  2. K-0…K-5 (fast publishing).
  3. K-7 (events editor).
- **Deploy:**
  - The Worker (`wrangler deploy`).
  - The CMS (`firebase deploy --only hosting:long-ky-admin`).
  - The app build (the user builds and uploads; the keystore stays with
    them).
- `melos analyze` and every suite stay green at each step.
- Claude checks the CMS and the app in a browser build. The final look is
  the user's call on the phone.

### Out of scope for K

- Migrating content to Firestore (per K5).
- Publishing a chosen subset of pending items (K1). Hold eras back with
  Draft.
- Automatic publishing on commit.
- Moving an event between eras, per-era character overrides and roster
  removal (Raw JSON still covers them).
- A custom domain for the CDN. `r2.dev` is Cloudflare's development URL,
  rate-limited and not edge-cached. A domain the user owns would fix that,
  but it isn't needed for this cycle.

## Next cycles (queued)

Carried-over UX audit findings (top-bar scrims, particles over text, Chào
cờ lyrics legibility, swipe-hint timing) are still parked — see
`21fb88b:EXECUTION.md`. J's scrim work may have covered "top-bar scrims";
re-check before re-proposing.
