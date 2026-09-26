# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: EXECUTING Cycle G (the Long Ký CMS). G-0 and G-1's code are done,
committed and verified; G-1's actual data migration is blocked on one setup
step below. Cycle F is fully shipped — what's left there is the user's own
hands in Firebase/Play Console (see "Paused" below).**

Cycle G in full: Flutter web on Firebase Hosting (`apps/admin`), a
Cloudflare Worker backend, media originals moving to a private
`long-ky-sources` R2 bucket, and publishing moving to GitHub Actions.
Decided: G3 Cloudflare Worker, G4 saves go straight to `main`, G5
`long-ky-admin.web.app`. Build order: G-0 foundations → G-1 sources to the
cloud → G-2 publish in CI → G-3 Worker → G-4 CMS app → G-5 Hosting deploy.

### Blocked — needs the user's hands before G-1 can finish

The R2 API token `rclone` uses is scoped to `long-ky-content` only;
`rclone lsd r2:long-ky-sources` returns **403 Access Denied**. In the
Cloudflare dashboard → R2 → **Manage API tokens** → edit the token rclone
uses (or create a new one) → add **`long-ky-sources`** to its bucket scope
with Object Read & Write → save. Tell Claude once it's done; the fix is on
Cloudflare's side only, nothing local to `rclone.conf` needs to change.

Also needed before **G-2** (CI publishing) can run for real: the R2
credentials as **GitHub Actions secrets** on `long-ky-app` (Settings →
Secrets and variables → Actions) — `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`
(the same pair rclone already uses locally), plus `R2_ENDPOINT` (from
`rclone config show r2` — the `.r2.cloudflarestorage.com` URL, not a secret
but convenient to keep alongside them).

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

### G-1 Sources to the cloud — code shipped, data migration blocked

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
- **Not yet run**: the actual one-time 3.4 GB upload — blocked on the R2
  token scope above, and needs your explicit yes before it runs regardless
  (per the standing rule on outward-facing, hard-to-fully-verify actions).

### G-2 through G-5 — not started

Queued next, in order: publish moving into a GitHub Actions workflow (needs
the Actions secrets above), the Cloudflare Worker backend, the `apps/admin`
Flutter app itself, then the Hosting deploy. Full detail for each was
captured in the planning session; ask Claude to recap any stage's spec if
picking this up in a new session.

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

Cycle G continues once the R2 token is fixed (see "Blocked" above).
Carried-over UX audit findings from an earlier cycle (top-bar scrims,
particles over text, the Chào cờ lyrics legibility, the swipe-hint timing)
are still parked — see git history (`21fb88b:EXECUTION.md`).
