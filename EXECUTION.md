# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: IDLE — code is done. What's left is the user's own hands in Play
Console (see "Paused" below).**

Cycle D (Câu đố) and the app-code half of Cycle E (three tip sizes) are
fully executed, verified and committed to `main`. No content changed, so
there was nothing to publish this cycle.

## Câu đố — shipped

- **`QuizGenerator`** (`packages/core_domain/lib/src/quiz/`): every question
  is built from an event or figure already in `content/`, never hand-written
  text. Five types — year, who, quote → event, order (4 events, chronological),
  era — each carrying the source event's real citation, shown after
  answering.
- **"Who" excludes 16 post-1975 heads of Party/State/Government** (Tôn Đức
  Thắng through Lương Cường; see `QuizGenerator.excludedLeaderIds`), per the
  history-not-politics stance. Found and fixed one gap live during this
  cycle's own smoke test: Lê Đức Anh (Chủ tịch nước 1992–1997) was missing
  from the list.
- **Four scopes:** daily (5, seeded by the calendar date so it's the same
  quiz for everyone), by dynasty (10), random (10), and a per-era 5-question
  quiz reached by a quiet "Thử sức kỷ nguyên này ›" link on every Era Hub.
- **Screens:** `quiz_home_screen.dart` (three mode cards, remembered best
  score, a ✓ once today's quiz is done) and `quiz_play_screen.dart` (one
  question at a time, instant feedback, the score shown inline — no separate
  route). Routes are a pure function of their query params, so "Chơi lại" is
  just a push with a new seed.
- **A new "Câu đố" row** in the Sảnh, right after Niên biểu.
- **`lib/state/quiz_store.dart`** persists best scores and the daily
  done-date the same way `ContentSync` persists a content pack (a small JSON
  file via `path_provider`; in-memory only on web). No new dependency.
- No streaks, badges or leaderboards — matches the delicate-UI rule.
- **Verified:** the generator ran across the full real 237-event corpus with
  no fixtures (`packages/core_domain/test/quiz_generator_test.dart`) —
  deterministic per seed, exactly one correct option among 4 distinct ones,
  the year/order spacing rules hold, no excluded leader is ever a "who"
  answer, every question resolves to a real event. Widget tests cover the
  Sảnh row, all three modes, an MCQ and an order question's feedback, a full
  5-question run to the score screen, and the era-hub link. A web smoke test
  at 375×812 walked one full daily quiz end to end (a wrong MCQ answer, a
  wrong order answer, three right answers, the score screen, and the
  remembered best score back on the quiz home).

## Tip sizes — shipped (app code)

- **Three consumable sizes**, capped low so nobody overspends: `long_ky_tea`
  ($0.99, một chén trà), `long_ky_tea_2` ($1.99, hai chén trà),
  `long_ky_tea_3` ($2.99, ba chén trà).
- `TipStore.load()` now returns every offer the store actually has; the
  Sảnh's tip row shows "từ `<lowest price>`" and opens a small sheet
  listing all loaded sizes with gold line-drawn 1/2/3-cup icons
  (`widgets/tea_cups_icon.dart`) — no commissioned art needed.
- No soft tip prompt anywhere outside the Sảnh (the user's call).
- iOS stays parked.

## Drafted for the Play Store (not yet published anywhere)

- `docs/play-store/privacy-policy.md` — bilingual, ready to paste onto
  binh-nt.dev. No accounts, no personal data, no analytics, no ads;
  purchases handled entirely by Google Play Billing. Two placeholders left
  for the user: contact email, last-updated date.
- `docs/play-store/data-safety-and-listing.md` — draft answers for Play's
  Data safety and content-rating questionnaires, the ads/target-audience
  declarations, and store-listing copy (VI/EN).

## Paused — needs the user's own hands in Play Console

Everything code-side is ready; what's left is store setup:

1. Create the upload keystore and `android/key.properties` (gitignored;
   Claude never reads, types or stores the passwords).
2. Tell Claude it exists — Claude raises the build number, builds the
   `.aab`, and verifies it carries the upload certificate.
3. Confirm Play App Signing is on and the payments profile is set up.
4. Upload to internal testing (Google only unlocks in-app products after an
   upload that carries the billing permission).
5. Create and activate the three `long_ky_tea*` products in Play Console.
6. Add the user's account under License testing.
7. Test-buy each size on the phone; confirm the thank-you sheet and that
   they're consumable.
8. Publish the drafted privacy policy at a public URL, paste the Data
   safety / content-rating answers into Play Console, and add the store
   listing (icon 512×512, feature graphic 1024×500, 2–8 screenshots).

## Next cycles (queued)

None currently queued beyond the Play Console steps above. Carried-over UX
audit findings from an earlier cycle (top-bar scrims, particles over text,
the Chào cờ lyrics legibility, the swipe-hint timing, and a few
low-priority ones) are still parked — see git history
(`21fb88b:EXECUTION.md`) if picking any of them up.
