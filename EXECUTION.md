# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: Cycle K shipped in code (K1–K7). Three manual setup steps left,
all in the user's hands — see "To turn Firestore on" below.**

## What shipped

- **K7 — events editor** (`5a9ec5b`): add/edit/delete/reorder events in the
  CMS, with a people picker that auto-adds to the era roster, a related-events
  picker, and a delete that cleans up references. Four new validator rules
  (id==slug, globally-unique event ids, contiguous order, resolvable
  relatedEventIds) — the 237 existing events already pass all four.
- **K1–K4 — incremental publish pipeline** (`a988e2b`): a ledger
  (`content/media-sources.json`) compared against a 1.2 s metadata-only R2
  listing finds exactly what changed; only that gets downloaded, converted
  and uploaded. Tested against the real buckets: an incremental run with
  nothing changed reproduces the manifest byte-for-byte in about 1 s.
  Removals happen only after the new pack is live. The CMS's "Publish for
  real" now requires a successful dry run of the *exact* commit being
  published, not just "some run succeeded once" (the old, weaker check).
- **K5 — Firestore for text**: Git stays the source of truth and the
  validation gate — nothing about commit → dry run → publish changed. What's
  new is where validated text ends up: `tool/publish_firestore.mjs` (Node +
  firebase-admin) writes each era/people/periods JSON file's exact canonical
  text into Firestore as one `{json: "..."}` document, alongside the R2 pack
  (kept, since every already-installed app version can only ever read that).
  The app's `FirestoreContentSource` reads it with a live listener, set as
  `OtaContentSource.liveOverlay` — tried before the R2 pack, which is tried
  before the bundled baseline. Every read has a 3 s timeout and turns any
  failure into the same exception the fallback chain already expects, so
  this is safe to ship **before** Firestore is even turned on for the
  project: every read just times out and falls through to the pack, exactly
  as today.
  - Media (images/video, the manifest) is untouched — still the R2/CDN path
    from K1–K4. Folding it into the live path too is a reasonable future
    step, not done here.
  - Firestore only initializes in the same conditions telemetry already
    does — release builds, not web. A debug build (what the user's own
    testing on a phone via `flutter run` most likely uses) **will not** see
    live Firestore updates; it still uses the R2 pack. This was a deliberate
    call to avoid changing when Analytics/Crashlytics activate, which the
    same `Firebase.initializeApp()` call also gates — flag it if debug-build
    live updates turn out to matter.
- **K6 — when a phone actually swaps in new text**: `ContentSwapGate`
  (pure, fully unit-tested) — a Firestore change swaps in at once if the
  reader is on Home, otherwise it waits for the next return to Home, so
  era/event text never changes mid-read. No banner, no prompt.
- **Tests:** 4 new validator tests + 7 new controller tests (K7); the
  incremental pipeline verified live against the real `long-ky-sources` /
  `long-ky-content` buckets (K1–K4); `OtaContentSource`'s new `liveOverlay`
  tier (4 tests), `ContentSwapGate` (6 tests), `FirestoreContentSync`'s
  wiring including the disabled/no-Firebase-app path (5 tests) — all in
  `core_content`/mobile. `melos analyze` and every suite are green: mobile
  156, core_content 18, core_domain 40, admin 31, the Worker 25.
  `firestore_content_sync_test.dart`'s off-Home case is a `testWidgets` (a
  bare `GoRouter` never reports its location until actually mounted — an
  unmounted one reads as permanently "on Home," which would make that test
  pass for the wrong reason).
- **Verified live in a browser build:** the app boots and Home renders
  identically with Firestore disabled (no Firebase app on web/debug) — no
  console errors. This is the "Firestore isn't configured yet" case every
  real user has until the three steps below happen.

## To turn Firestore on (the user, not Claude — never handles credentials)

1. **Enable Firestore** for the Firebase project (console → Build →
   Firestore Database → Create database). Native mode, any region close to
   most readers.
2. **Paste `firestore.rules`** (repo root) into Firestore's Rules tab and
   publish it. Public read, no client write — every write goes through the
   publish script's service-account credential, which bypasses rules
   entirely, so `allow write: if false` is the only thing stopping a
   client from writing directly.
3. **Create a service account** with the "Cloud Datastore User" role (or
   Firestore-specific write access), download its JSON key, and add its
   *entire contents* as a GitHub Actions repo secret named
   `FIREBASE_SERVICE_ACCOUNT_KEY`. Until this exists, `publish_firestore.mjs`
   skips itself cleanly on every publish — nothing breaks, the app just
   keeps using the R2 pack.
4. **One-time bootstrap:** with that same key available locally (never
   pasted to Claude), run:
   ```bash
   cd tool && npm ci --omit=dev
   FIREBASE_SERVICE_ACCOUNT_KEY="$(cat /path/to/key.json)" node publish_firestore.mjs
   ```
   This writes all 38 eras + people + periods once. Every publish after
   that keeps it current automatically.
5. **Build and upload a new app version** with `cloud_firestore` in it —
   1.0.2+4 predates this change. The keystore stays with the user, as
   always.

## Audit of the previous plan (nothing else changed this cycle)

**Cycle J is fully shipped in code** (`fe6a54d`, pushed):
- Home follows the EN toggle, and the choice persists.
- The event list is readable (~5.3–5.8:1 contrast).
- The Atlas is in English.
- The period rail is a drag scrubber; KHÁM PHÁ moves to the next period.

**The wording issue flagged last round is still open:** the user's CMS edit
(`70b6f12`) left `periods.json`'s Kỷ nguyên mới `yearRange.display.vi` and
`ky-nguyen-vuon-minh`'s `kicker.vi` reading "2020 – now" — probably meant
"2020 – nay". Fix in the CMS whenever convenient.

**Still open, in the user's hands:**
1. The three Firestore setup steps above, whenever suits — publishing keeps
   working exactly as before until they're done.
2. Build and upload a new app version (bundles cloud_firestore + the whole
   Cycle J/K app-side work — 1.0.2+4 was never uploaded).
   - Then check on the phone: the period scrubber, the 17 new portraits,
     and — once steps 1–4 above are done — that a CMS edit shows up quickly
     without restarting the app.
3. **Play closed test (gates production):** at least 12 testers opted in
   for 14 days straight. Aim for about 15, and ask them to actually open
   the app.
4. Firebase → Analytics → Custom definitions: `era_slug`, `event_id`,
   `figure_id`.
5. Deploy the privacy page. Make Play's Data safety form match
   `docs/play-store/data-safety-and-listing.md`.
6. From Cycle E: the `long_ky_tea*` products, license testing, a test
   purchase, screenshots, the feature graphic.
7. Optional: delete the unused Hosting site `admin-long-ky.web.app`.

**Known caveat, not a task:** an era with `draft: true` stays out of both
the R2 pack and Firestore (K5's write script reads `content/index.json`,
which `build_content_pack.dart` already filters — draft eras never reach
either). No era is a draft today.

## Next cycles (queued)

- Fold the media manifest into the Firestore live path too, so a replaced
  image's new URL also arrives without a restart (deferred from K5).
- Carried-over UX audit findings (top-bar scrims, particles over text, Chào
  cờ lyrics legibility, swipe-hint timing) are still parked — see
  `21fb88b:EXECUTION.md`. Cycle J's scrim work may have covered "top-bar
  scrims"; re-check before re-proposing.
