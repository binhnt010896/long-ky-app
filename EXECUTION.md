# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: IDLE — Cycle F (Firebase Analytics + Crashlytics) is fully
executed, verified and committed. What's left is the user's own hands in
Firebase/Play Console (see "Paused" below) before this build goes out.**

Cycle G (the Long Ký CMS) is still only planned — see git history
(`EXECUTION.md` as of the "plan Cycle F/G" commit) for the full spec if
picking it up next: Flutter web on Firebase Hosting, a Cloudflare Worker
backend, media originals moving to a private `long-ky-sources` R2 bucket,
and publishing moving to GitHub Actions. Decided there: G3 Cloudflare
Worker, G4 saves go straight to `main`, G5 `long-ky-admin.web.app`.

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

Cycle G (CMS) as summarized above, once the user wants to pick it up.
Carried-over UX audit findings from an earlier cycle (top-bar scrims,
particles over text, the Chào cờ lyrics legibility, the swipe-hint timing)
are still parked — see git history (`21fb88b:EXECUTION.md`).
