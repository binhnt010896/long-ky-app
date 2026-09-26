# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: EXECUTING Cycle G (the Long Ký CMS). G-0 through G-4 are done:
code committed, `melos analyze`/`flutter analyze`/`flutter build web` all
clean, and the sign-in gate verified live in a browser against the
redeployed Worker. G-5 (the actual Hosting deploy) is next — it needs the
user's explicit yes, since it makes the CMS reachable at
`long-ky-admin.web.app`. Cycle F is fully shipped — what's left there is
the user's own hands in Firebase/Play Console (see "Paused" below).**

Cycle G in full: Flutter web on Firebase Hosting (`apps/admin`), a
Cloudflare Worker backend, media originals moving to a private
`long-ky-sources` R2 bucket, and publishing moving to GitHub Actions.
Decided: G3 Cloudflare Worker, G4 saves go straight to `main`, G5
`long-ky-admin.web.app`. Build order: G-0 foundations → G-1 sources to the
cloud → G-2 publish in CI → G-3 Worker → G-4 CMS app → G-5 Hosting deploy.

**Note on push/deploy access**: this environment had no `git push`/`gh`
access at first (no SSH key). Fixed mid-cycle: the user ran `gh auth login`
with "Authenticate Git with your GitHub credentials? Yes", which set up an
HTTPS credential helper — switching `origin` to the HTTPS remote URL then
let both `git push` and the `gh` CLI work directly from this environment.
Worth remembering for any future session that hits the same wall.

### Deployed / live

- **Worker**: `https://long-ky-cms-api.binhnt-010896.workers.dev` — smoke
  tested with a bare `curl`, correctly returns `401
  {"error":"Missing bearer token"}` rather than a silent pass-through.
- **GitHub Actions secrets** (`R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`,
  `R2_ENDPOINT`) and the Worker's `GITHUB_TOKEN` secret are both set.

## Cycle F — shipped

- **`flutterfire configure`** wired the app to the `long-ky-app` Firebase
  project (`lib/firebase_options.dart`, `android/app/google-services.json`).
  Web/iOS deliberately throw — Firebase never runs there.
- **`lib/telemetry/`** — `Telemetry` (screen/event/recordError/setEnabled),
  `FirebaseTelemetry` (real) and `NoopTelemetry` (web + **all debug
  builds**, so local testing never pollutes the numbers).
  `telemetryProvider` picks one by `kIsWeb`/`kReleaseMode`.
- **Screen tracking**: `route_telemetry.dart`'s `mapUriToScreen` maps every
  route in `app_router.dart` to a fixed `screen_name` (e.g. `era_hub`,
  `event_detail`) + id params (`era_slug`, `event_id`, …);
  `RouteTelemetryObserver` listens on the router's delegate and logs
  `screen_view` on every navigation. Home logs a separate debounced
  `era_card_view {era_slug, period_id}` (~1s settle) since its two nested
  PageViews aren't routes.
- **Events**: `quiz_start`/`quiz_answer`/`quiz_complete`,
  `source_link_open`, `chao_co_play`, `atlas_era_change` (debounced),
  `tip_sheet_open`/`tip_result`, `content_pack_adopted` — wired at each
  site listed in the plan.
- **Crashlytics**: `main.dart` wires `FlutterError.onError` +
  `PlatformDispatcher.instance.onError` as fatal reports. The four
  previously-silent `catch (_) {}` sites with real failure signal
  (`ContentSync.bundledVersion`/`startup`/`checkForUpdate`'s pack-parse
  step, `StoreTipStore.load`/`buy`/purchase-stream, `FileQuizStore.load`/
  `recordResult`) now also call `reportNonFatal` — routine, expected
  failures (background media prefetch on a bad connection, an unavailable
  billing platform) were deliberately left silent to avoid Crashlytics
  noise.
- **No ad machinery**: `AndroidManifest.xml` strips
  `com.google.android.gms.permission.AD_ID` **and** its Android 13+
  Privacy Sandbox equivalents (`ACCESS_ADSERVICES_AD_ID`,
  `ACCESS_ADSERVICES_ATTRIBUTION`) — all three turned out to be pulled in
  by Firebase's measurement SDK, found by inspecting the actual dependency
  AARs, not just the one permission the plan named. Plus the
  `google_analytics_adid_collection_enabled`/
  `google_analytics_default_allow_ad_personalization_signals` meta-data
  flags. Verified absent from the merged release manifest;
  `com.android.vending.BILLING` still present.
- **The off switch**: "Gửi thống kê ẩn danh" in Về Long Ký, default **on**,
  no prompt — `telemetry/telemetry_settings.dart` persists it the same way
  `QuizStore` persists progress (a small JSON file, in-memory on web).
- **Paperwork updated**: `docs/play-store/privacy-policy.md` (§8, both
  languages) and `docs/play-store/data-safety-and-listing.md` now describe
  Analytics/Crashlytics honestly — **must be re-pasted into Play Console
  and the live privacy-policy page before this build is uploaded.**
- **Version bumped** `1.0.0+2` → `1.0.1+3`.
- **Verified**: `packages/*` and the app's full test suite (129 app tests,
  including 6 new ones in `test/telemetry_test.dart` covering the route→
  screen map, a full navigation sequence, the debounced `era_card_view`,
  a full quiz run's event sequence, and the on/off switch) all pass;
  `melos analyze` clean across every package; a signed release `.aab` was
  built and `jarsigner -verify` confirms it's signed by the real upload key
  (`CN=Thanh-Binh Nguyen`), not the debug cert.
- **Gradle note**: bumped `com.google.gms.google-services` to 4.4.3 (the
  Crashlytics Gradle plugin 3.x requires ≥4.4.1) and added the Crashlytics
  Gradle plugin. The pre-existing "failed to strip debug symbols" warning
  (missing `cmdline-tools`, noted in Cycle E) is unrelated and still
  non-blocking.

## Cycle G — progress

### G-0 Foundations — shipped

- **`ContentFormatter`** (`packages/core_domain`): canonical JSON layout —
  every value on its own line, 2-space indent, original key order. A plain
  uniform expansion (what `JSON.stringify(data, null, 2)` naturally
  produces) rather than the old hand-tuned "collapse a short `{vi,en}`
  object onto one line" style, so a CMS save or a hand edit always diffs as
  just the field that changed.
- **`ContentValidator`** (`packages/core_domain`): the schema +
  referential-integrity checks that used to live directly in
  `tool/validate_content.dart`, now a pure function over raw JSON strings
  (no file I/O) — the exact same code the CMS will call later against an
  in-memory draft, before anything is saved.
- **`tool/format_content.dart`** (new) and **`tool/validate_content.dart`**
  (unchanged CLI output, now a thin wrapper around `ContentValidator`).
- **`.github/workflows/content-check.yml`** — the repo's first CI: canonical
  formatting, schema/referential validation, and `core_domain`'s test suite
  (loads the whole real content corpus) on every push/PR touching
  `content/` or `core_domain`. Not yet exercised on a real push — will show
  green (or not) on the next one.
- **The one-time reformat**: all 46 `content/**/*.json` files rewritten to
  canonical form, as its own mechanical `style(content):` commit. Verified:
  every file's *decoded* JSON is byte-identical before/after (a
  `DeepCollectionEquality` check across all 46 files), and the formatter is
  idempotent (`format_content --check` is clean immediately after).
- **Verified**: 8 new unit tests for `ContentFormatter`/`ContentValidator`
  (idempotency, data-preservation, every real file already canonical, a
  forced schema violation, a forced bad person-ref, the index-check being
  skippable) plus the full existing suite (129 app tests + all packages)
  and `melos analyze` all pass.

### G-1 Sources to the cloud — shipped, fully verified

- **`tool/push_sources.sh`** / **`tool/pull_sources.sh`**: copy-only
  up/down sync between `content/`'s gitignored media and the private
  `long-ky-sources` R2 bucket — copy-only in both directions so the Mac,
  the CMS, and CI can never race and delete each other's uploads.
  `push_sources.sh --check` reports unpushed media without uploading.
- **`tool/publish_content.sh`** now refuses a real publish (not `--dry-run`)
  unless `push_sources.sh --check` is clean — otherwise a publish run from
  wherever the CMS/CI runs later (which starts from `long-ky-sources`, not
  this disk) could delete a served image whose only original is on this
  Mac.
- **The one-time upload ran** (2026-09-26, after fixing the R2 token's
  bucket scope and the user's explicit go-ahead): **681 files, 3.369 GiB**,
  0 errors. `push_sources.sh --check` now reports "0 differences found,
  681 matching files" — the Mac is no longer the only copy of this art.

### G-2 Publish in CI — shipped, verified live

- **`.github/workflows/publish-content.yml`** — manual trigger
  (`workflow_dispatch`, `dry_run` input). Pulls originals from
  `long-ky-sources`, runs the same format/validate/test gate as
  `content-check.yml`, then `tool/publish_content.sh` (or `--dry-run`); a
  real publish commits `content-version.json`/`media-manifest.json` back to
  `main` itself.
- **Ran for real** (`dry_run=true`, run
  [36226183243](https://github.com/binhnt010896/long-ky-app/actions/runs/36226183243)):
  every step green — rclone/cwebp install, pulling 681 files from
  `long-ky-sources`, the format/validate/test gate, and the media
  conversion (627 files, 3.60 GB → 0.25 GB served). "Publish" and "Commit
  the published version bump" correctly stayed skipped for the dry run.
- **Found a real, pre-existing content gap in the process**: the dry run's
  media-conversion step warned `referenced media not found on disk:
  eras/hai-ba-trung/scene/ridge-far.png` and `ridge-near.png` —
  `hai-ba-trung.json` has referenced these two scene layers since the era
  was built, but the files were never generated (not on the Mac, not in
  `long-ky-sources`, never in a published manifest). Not a Cycle G
  regression — the old validator only checks JSON structure, never whether
  a referenced path actually exists on disk. Parked as a content fix,
  not yet actioned (ask the user before generating the missing art).

### G-3 Worker — shipped and deployed

- **`services/cms_api/`** (TypeScript, Hono, on Cloudflare Workers) — see
  its own README for the endpoint list. Holds the GitHub token (a Worker
  secret) and R2 access (a bucket binding) the CMS itself can never safely
  hold. Auth: Firebase ID token verified against Google's JWKS, checked
  against an email allowlist.
- **Verified**: 17 tests (`@cloudflare/vitest-pool-workers`, a real
  in-memory R2 simulator, a fake `fetch` for GitHub's API) — auth refuses a
  missing/foreign/unverified/non-allowlisted token, a moved `main` throws
  `ConflictError` (409) without writing anything, a real multi-file commit
  sequences correctly, media uploads are type/size-checked before touching
  R2. `tsc --noEmit` clean.
- **Deployed**: `https://long-ky-cms-api.binhnt-010896.workers.dev` (first
  deploy also registered the account's `workers.dev` subdomain and created
  the Worker). Live smoke test: an unauthenticated `GET /content` correctly
  returns `401 {"error":"Missing bearer token"}`, not a silent pass-through.

### G-4 (the CMS app itself) — shipped

Built as planned, with two scope cuts made during execution (both flagged
here rather than silently shipped):
- **People/Periods editors are whole-file raw JSON**, not a per-person
  guided form — `content/people.json`/`content/periods.json` are single
  shared registries, so there's no natural field-by-field form without a
  schema change (which this cycle explicitly avoids). The photo-fidelity
  step is a CMS-only checklist (an in-memory checkbox per person with a
  portrait) — nothing is written to the file; it's a reminder, not data.
- **Preview is a plain rendered summary** (title/kicker/subtitle/overview/
  events in a phone-frame), not the real app screens via
  `contentRepositoryProvider` — wiring `core_content`/`experience` in (CDN
  media loading, routing, theming) was too large an integration for this
  pass. Good for a bilingual-text/event-order sanity check; not a
  substitute for checking the real app before publishing.

Everything else matches the original plan: Google sign-in gated by the
Worker's own allowlist check, a `GET /content` draft keyed by `baseSha`,
era editor (guided title/kicker/subtitle/overview + raw-JSON fallback for
events/characters/citations), media upload/preview via the Worker (never
touches R2 directly) with pinch-zoom for corner/transparency checks,
and a publish page that gates a real publish on a successful dry run.

**Also done as part of G-4**: the Worker's CORS now allows `localhost`
origins alongside `CMS_ORIGIN` (Flutter web's dev server), redeployed and
verified with a live `OPTIONS` preflight from a `localhost` origin.

**Verified**: `flutter analyze` clean, `flutter build web` succeeds, and
the sign-in screen renders correctly behind GoRouter's auth redirect in a
live browser preview against the real (redeployed) Worker — actually
signing in needs the user's own Google account, so that's still a G-5 step.

**Pre-flight, done before writing code:**
- Firebase web app "Admin Panel" (`1:240841070468:web:178cf934c969d76011efd1`)
  and Hosting site `long-ky-admin` (→ `long-ky-admin.web.app`) both already
  exist and are linked, confirmed via `firebase apps:list` /
  `firebase hosting:sites:list`.
- Worker CORS currently allows only `CMS_ORIGIN` (the production origin) —
  needs `http://localhost:*` added and the Worker redeployed before local
  dev against the live Worker works.

**Structure**: `apps/admin`, a plain Flutter web app (no mobile/desktop
targets), added to the root `pubspec.yaml` workspace list and left under
Melos's existing `apps/**` glob. Depends on `core_domain` (reuses
`ContentFormatter`/`ContentValidator` verbatim — same canonical-format and
validation code as the CLI/CI) and `firebase_auth`/`firebase_core`/
`google_sign_in` for auth. Talks to the Worker over plain `http`, never
touches GitHub or R2 directly.

**Screens** (Riverpod, same pattern as `apps/mobile`):
1. **Sign-in** — Google sign-in via Firebase Auth. Non-allowlisted emails
   get a clear "not authorized" message (the Worker enforces this for real;
   the UI check is just a good error message).
2. **Dashboard** — counts (eras/people/periods), a publish-status chip, nav
   to the editors.
3. **Era editor** — list eras, edit one era's JSON (guided form for known
   fields: id/title/dates/summary/sources; raw-JSON fallback for anything
   the form doesn't cover, so unknown fields always round-trip).
4. **Event editor** — nested under an era; citation field required before
   save (client-side check; `ContentValidator` is the real gate).
5. **People registry** — the shared `content/people.json`; per-person
   fields plus a free-text confirmation note for photo/era accuracy (no
   schema change — [[people-registry]], [[camera-photo-fidelity]]).
6. **Periods editor** — `content/periods.json`.
7. **Media** — upload (`PUT /media`) and preview (`GET /media`) originals in
   `long-ky-sources`; corner-zoom on preview to check transparency
   ([[higgsfield-restore-pitfalls]] muscle memory, done in-browser here).
8. **Preview** — phone-frame chrome rendering the *real* app screens via a
   `contentRepositoryProvider` override pointed at the in-memory draft, not
   a mockup.
9. **Publish** — dry run against the Worker's `/publish`, show the GitHub
   Actions run status (`/publish/status`), then a real publish gated on the
   dry run having passed.

**Editing model**: `GET /content` once per session into an in-memory draft
keyed by the `baseSha` it returned; every editor mutates that draft; `POST
/commit` sends the whole diff atomically. A 409 (main moved) surfaces as
"reload and redo your edit" — no merge UI, per G-4's own conflict policy.

**Language**: English CMS labels (this is Claude's/the admin's tool, not
the public app — no i18n needed).

**Build order**: sign-in → dashboard shell → era/event editors → people
registry → media → phone-frame preview → publish page. Each stage gets its
own commit; `melos analyze`/tests stay green throughout.

### G-5 (Hosting deploy) — not started

`flutter build web` in `apps/admin` → `firebase deploy --only
hosting:long-ky-admin` (needs the user's explicit yes — this makes the CMS
publicly reachable, even though it's gated by Firebase Auth + the email
allowlist). The user may need to add `long-ky-admin.web.app` to Firebase
Auth's authorized domains (Authentication → Settings → Authorized domains)
before Google sign-in works there; `localhost` is authorized by default so
local dev is unaffected. The user does the first live end-to-end sign-in
test themselves.

There is also a second, unlinked Hosting site `admin-long-ky.web.app`
(probably a first-attempt leftover) — flagged for the user to delete or
keep; not used by anything in this cycle.

## Paused — needs the user's own hands

1. In Firebase console → Analytics → Custom definitions, register
   event-scoped dimensions `era_slug`, `event_id`, `figure_id` once the
   first real data arrives (otherwise GA4 can say a screen was viewed but
   not which era/event/figure).
2. Re-paste the updated privacy policy at binh-nt.dev (fill the two
   placeholders first, per Cycle E's note) and update the Data safety /
   content declarations in Play Console to match
   `docs/play-store/data-safety-and-listing.md` — **before** uploading this
   build; Play rejects a release whose SDKs contradict a stale form.
3. Upload `apps/mobile/build/app/outputs/bundle/release/app-release.aab`
   (or a fresh build off this commit) to a release.
4. Everything else from Cycle E is still open too: confirm the payments
   profile clears bank verification, create and activate the three
   `long_ky_tea*` products, license testing, a real test purchase, the
   Vietnamese store listing, screenshots/feature graphic.

## Next cycles (queued)

Cycle G continues once the GitHub Actions secrets are set (see "Blocked"
above). Carried-over UX audit findings from an earlier cycle (top-bar scrims,
particles over text, the Chào cờ lyrics legibility, the swipe-hint timing)
are still parked — see git history (`21fb88b:EXECUTION.md`).
