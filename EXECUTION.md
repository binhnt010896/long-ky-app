# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: Cycle S D-0…D-3 are BUILT (2026-10-23), not released.** Tests: core_domain
147, core_content 32, mobile 362, admin 65, all green on Flutter 3.47.7 and on
3.44.9 (Dart 3.12.2, the repo's floor); `validate_content`, `format_content
--check` and the JS inlining test pass. **Not built or run on a device:** the
Android and iOS native changes (no SDK here), so the reminder has never fired
on a phone. **Waiting on the user:**
1. The phone check in D-4 below, Android and iOS, before any release.
2. Approve `docs/anniversaries-review.md` (66 candidate events, 97 dates), then
   enter the approved ones in the CMS. Until then no event has an anniversary,
   so "Hôm nay" always shows the rotation.
3. The D-0 baseline: note Day 1/7/30 retention in Firebase before release 1.
4. Version bump and bundle (D-4); update the privacy page and the Play Data
   safety answers for the notification permission (it is a new permission).
5. The six decisions below were built as recommended; say if any should change.

**Built differently from the plan (read these):**
- **No kicker on the item pages.** The kicker ("Ngày này năm 1975") shows on the
  Sảnh card only. Putting it above the title on the four detail screens would
  touch four layouts I could not see on a device.
- **The card is text-only** (kicker, title, one line), no avatar or hero.
- **Timezones without a plugin.** Reminders are scheduled as absolute instants
  in UTC (`tz.UTC`), so no `flutter_timezone` and no timezone database.
- **`/hom-nay` has no logged screen of its own** (it redirects), so `today_open`
  is logged where it is opened (`sanh` or `notification`). `mapUriToScreen` maps
  it anyway.
- **Lockfile.** `xml` and `petitparser` are pinned to 7.0.1 / 7.0.2 (the newest
  that support Dart 3.12); the latest need Dart 3.13. They come in only through
  the Linux/Windows halves of the notifications plugin.
- **Fixed on the way:** `kAppVersion` said 1.2.0 on a 1.3.0 build (it was failing
  `about_privacy_test` on main). The CMS event dialog dropped any key it did not
  know on save; it now keeps `anniversary`.
- **Already on main, not touched:** `apps/mobile/pubspec.yaml` lists
  `assets/content/chao-co/`, which does not exist (an analyzer warning), and
  `tool/gen_media_manifest.dart` has 3 lint infos.

Earlier specs: M `cfa220a`, N `92e699f`, O `f56a4d7`, P `9552bb5`, Q `84d5ed8`,
R `a150c78` (each `<sha>:EXECUTION.md`).

> Naming: this cycle's parts are **D-0 … D-4** ("daily"), because `S0`–`S5`
> already name the street-map speed plan in `docs/wave-e-plan.md`.

## Audit of the previous plan

Done since `a150c78` (from `git log`):
- Content packs published six times, 2026-10-16 → 2026-10-21 (`fd79463` …
  `540b19f`).
- Spoken narration for eras, people and events (`6b784a9`), all 597 clips
  (`d806b41`), and playback in the CMS (`a54aa71`).
- The landing site `apps/landing` (`6f3696d` and after), the iOS build fix
  (PR #3), the new chop logo (`6f14539`, `b0ed036`), and an easier-to-find
  street map (`3cf5965`).
- App version **1.3.0+13** (`2d60d3b`).
- The street mapping now has **285 approved streets** (`content/streets/hcm.json`),
  which reaches the Wave D target (284) in the R table.

**I can't check these from the repo, so ask the user:** the Play closed test,
the R-6 phone checks, the Data safety form, the Analytics custom definitions,
Firestore (still off?), and deleting `admin-long-ky.web.app`.

## Cycle S — what the user asked for

> Any idea to make users more engaged to our app? Something that makes them
> come back everyday. I can't think of a reward for showing up.
>
> OK draft them in EXECUTION.md. No execution.

**The idea:** the reward for coming back is something that **only exists
today** and that the user can see building up. No points and no streaks.
Three features, cheapest first:

| Part | What | Needs an app release | Content work |
|---|---|---|---|
| **D-1** | Share the daily quiz result (a Wordle-style grid) | yes (new plugin) | none |
| **D-2** | "Hôm nay": today's event or person, plus an opt-in daily notification | yes | anniversary dates on events (CMS) |
| **D-3** | The street map fills in with the streets you have discovered | yes | none |

D-0 (measure) comes first, and D-4 ships everything.

**The delicate-UI rule stays.** The code cites it as "No streaks, badges or
leaderboards" (`apps/mobile/lib/screens/quiz/quiz_home_screen.dart:15`) and
`[[delicate-ui-no-nags]]` (`apps/mobile/lib/state/content_swap_gate.dart:7`).
Nothing in Cycle S punishes a missed day. The notification is opt-in and has an
off switch. (The rule's full text is not in this repo; its CLAUDE.md is local.)

## Decide before building

1. **What gets shared (D-1).** I recommend **the first attempt of the day
   only**, like Wordle. Replaying stays allowed and still records the best
   score, but the shared grid doesn't change.
2. **The grid's squares (D-1).** I recommend 🟨 for a right answer and ⬛ for a
   wrong one (the lacquer-and-gold palette). The alternative is Wordle's 🟩 / ⬜.
3. **Where "Hôm nay" lives (D-2).** I recommend **a card at the top of Sảnh**,
   above Chào cờ. A fourth button on Home's chrome row (timeline, streets,
   seal: `home_screen.dart:441–470`) would crowd it.
4. **When to ask about notifications (D-2).** I recommend **once, right after
   the first finished daily quiz or the first "Hôm nay"**, never at launch.
   The user picks the time on that sheet; it starts at 08:00.
5. **Lunar anniversaries (D-2).** I recommend **yes**. Pre-modern dates in the
   chronicles are lunar (for example, Giỗ Tổ Hùng Vương is 10/3 âm lịch).
   They resolve to this year's solar date on the device (D-2a).
6. **Showing a count (D-3).** I recommend **a tint on the map and one quiet line in the filter
   sheet** ("Đã khám phá 41/285 con đường"), not a headline number.

## What I measured (read-only, 2026-10-23)

- **Content:** 247 events (`content/events.json`; the era files reference them
  by `ref`), 312 people (`content/people.json`), and 285 approved streets
  whose targets are 257 people, 29 events and 12 eras.
- **Dates:** an event has only a `year` (`YearRef`:
  `display`/`value`/`approximate`, `packages/core_domain/lib/src/year.dart`).
  A regex for "ngày D tháng M" and "ngày D/M" over the Vietnamese text found
  **66 of 247 events** with a day and month, covering **79 distinct calendar
  days**. This is raw: some matches are dates of side events rather than the
  event's own date. Every one needs review (D-2c).
  - Examples: 30/4 (`chien-dich-ho-chi-minh`), 2/9 (`cach-mang-thang-tam`,
    `a80`), 7/5 (`dien-bien-phu`), 3/2 (`dang-cong-san-ra-doi`).
  - Coverage by month runs from 2 days (October) to 10 (January and
    September), so **most days have no anniversary**. Those days need a
    fallback (D-2a).
- **The daily quiz:**
  - It has 5 questions, and its seed is `y*10000 + m*100 + d` of the device's
    local date (`quiz_generator.dart:31`).
  - It is the same for everyone **only on the same content version**, because
    the questions are generated from the active pack.
  - "Play again" replays the same daily quiz (`_playAgain`,
    `quiz_play_screen.dart:189`) and keeps the best score.
  - Only `bests` and `dailyDoneDate` are persisted (`quiz_store.dart`). The
    per-question results exist only in memory (`_missed`).
- **Plugins:** `apps/mobile/pubspec.yaml` has no share plugin and no
  notification plugin.
- **Old builds and a new event field:** on the device, a pack is parsed by Dart
  `fromJson`, which reads only known keys
  (`ContentPack.parseAndValidate` → `HistoryEvent.fromJson`), so **an additive
  key is safe for old builds**. But `content/event.schema.json` sets
  `additionalProperties: false`, so the schema, `validate_content` and the CMS
  must learn the key **before** any content uses it.
- **Telemetry:** Android release builds only. iOS and web are a no-op
  (`main.dart:25`, `telemetry.dart:13`), so **retention can be measured only on
  Android**.
- **Visit history already exists, partly:** `NarrationPrefs.heard` stores
  `eras/<slug>`, `people/<id>` and `events/<id>` for every narration played
  once (`narration_store.dart`). D-3 uses it to back-fill.
- **One place to see every page open:** `mapUriToScreen`
  (`telemetry/route_telemetry.dart`) already turns any route into a screen
  name plus its ids.
- **Download link:** `https://long-ky.com/get` exists
  (`apps/landing/public/_redirects`). It shows the coming-soon page until the
  Play listing is public. The app has no app-link intent filter, so a shared
  link cannot open the app directly (out of scope).
- **A map lesson:** coloring every street by period was reverted as "a rainbow"
  (`docs/street-period-colors-plan.md`). D-3 uses **two tones only**.

## D-0 — Measure first (the user, ~10 minutes)

- Before D-1 ships, note **day 1, 7 and 30 retention** from the Firebase
  Analytics console (Android) as the baseline. Re-read it 4 weeks after each
  release.
- New events, added to the fixed taxonomy and to `telemetry_test.dart`:
  - `quiz_share` `{quiz_mode, score}`;
  - `today_open` `{source: sanh | notification, kind: anniversary | rotation}`;
  - `notif_optin` `{granted: 0|1}`;
  - `notif_toggle` `{on: 0|1}`.
- New routes (`/hom-nay`) get a `mapUriToScreen` entry. Every route must have
  one (Cycle F rule).

## D-1 — Share the daily quiz

**Store** (`apps/mobile/lib/state/quiz_store.dart`):
- `QuizProgress` gains `dailyFirst: {date: 'yyyy-mm-dd', marks: [bool…]}`.
- It is written **only** when the day's first daily run finishes, and replays
  never overwrite it.
- It is an additive key in `progress.json`, so an old file still loads (the
  existing `load()` ignores unknown keys).

**Play screen** (`quiz_play_screen.dart`):
- Track a `List<bool> _marks` beside `_score`, and pass it to `recordResult`.
- In `_ResultView`, **for the daily mode only**, add a "Chia sẻ / Share"
  button above "Play again". It uses the first attempt's marks (decision 1),
  so a replay shows "Lần chơi đầu: 4/5" as the shared result.

**Share text** (plain text, through `share_plus`):
```
Long Ký · Câu đố hôm nay 23/10/2026
🟨🟨⬛🟨🟨  4/5
long-ky.com/get
```
- English when the app language is EN ("Long Ký · Today's quiz").
- Never reveal the answers.
- The squares follow decision 2.

**Tests:**
- Store round trip with `dailyFirst`, and that a replay does not overwrite it.
- An old `progress.json` with no `dailyFirst` still loads.
- The result view shows Share only in the daily mode.
- The share text for VI and EN: 5 squares, the right score, no answer text.

**Platform:** `share_plus` is a native plugin, so it needs an app release.
Check the iOS share-sheet anchor on iPad (`sharePositionOrigin`).

## D-2 — "Hôm nay" and the daily notification

### D-2a — Domain (`packages/core_domain`, pure and deterministic)

**Content field:** an optional event key, a sibling of `year`:
```json
"anniversary": { "month": 4, "day": 30, "calendar": "solar" }
```
- `calendar` is `solar | lunar`.
- Validator: month 1–12; day 1–31 for solar or 1–30 for lunar; at most one
  per event. It is allowed on legend events too, such as Giỗ Tổ.

**Vietnamese lunar conversion:**
- Port Hồ Ngọc Đức's published algorithm, computed for **UTC+7**, into
  `core_domain`.
- **Don't** use a Chinese (UTC+8) lunar library. The two calendars differ on
  some dates; Vietnam's Tết fell a month before China's in 1985
  ([Tết](https://en.wikipedia.org/wiki/T%E1%BA%BFt),
  [Hồ Ngọc Đức's rules](https://informatik.uni-leipzig.de/%7Educ/amlich/calrules_en.html)).
- Leap months: a lunar anniversary matches only the regular month.
- Tests: Tết solar dates for ~20 years, from a published table, including
  1985.

**`todayPick(date, events, people, streets)` → `TodayItem`:**
1. **Anniversary:** events whose anniversary is today (solar), or today's lunar
   day and month (lunar).
   - If several match, prefer a round number of years (`(year - eventYear) % 10 == 0`),
     then break ties with `dailySeed`.
   - The kicker is "Ngày này năm 1975" / "On this day in 1975". A round number
     adds "· 50 năm" / "· 50 years ago".
2. **Otherwise, rotation:** all people and events that have narration, in a
   shuffled order seeded by the year, indexed by day of year. There are 559
   items for at most 366 days, so **nothing repeats within a year**.
   - Prefer items that a street points to, so the pick lights a street in
     D-3.
   - The kicker is "Nhân vật hôm nay" or "Sự kiện hôm nay".
3. The pick is the same on every device with the same content version, like
   the daily quiz. Post-1975 leaders are left out of the rotation
   (`QuizGenerator.excludedLeaderIds`), per the history-not-politics stance.
   Their anniversary events still count.

### D-2b — App

- **The route `/hom-nay`** resolves `todayPick` and redirects to the item's
  route (`/su-kien/:id` or `/nhan-vat/:id`, which redirect on to the era
  route), the same pattern as the `/su-kien/:id` redirect in
  `app_router.dart:141`.
  - The item page shows the kicker above its title (a query param
    `?from=hom-nay`).
  - Narration follows the existing autoplay rule (it fires on a first visit
    only).
- **The Sảnh card** (decision 3): kicker, title, the avatar or hero, and a
  "✓ đã xem" mark once opened today. The opened date lives in a small
  `TodayStore` with the same file pattern as `quiz_store.dart`. Its design
  matches `_ChaoCoCard` and `_StreetsCard` (`sanh_screen.dart`).
- **The notification** (`flutter_local_notifications` + `timezone`):
  - Opt-in only (decision 4). Ask through an in-app sheet first, then the OS
    prompt:
    - Android 13+: the `POST_NOTIFICATIONS` runtime permission
      ([Android](https://developer.android.com/develop/ui/views/notifications/notification-permission));
    - iOS: the authorization request.
  - **Schedule the next 14 days** as single notifications, each titled with
    that day's pick (for example, "Ngày này năm 1954 · Chiến thắng Điện Biên
    Phủ"). The picks are computed on the device, so no server is needed.
    - Re-schedule on every app start and when a new content pack is
      adopted.
    - 14 is well under iOS's 64 pending notifications per app
      ([Apple forum, DTS](https://developer.apple.com/forums/thread/811171)).
  - **Inexact** scheduling, with no `SCHEDULE_EXACT_ALARM`. That permission is
    denied by default for new installs on Android 14
    ([Android 14](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms)),
    and a history note doesn't need to arrive on the minute.
  - Follow the plugin's Android setup (its boot receiver, so the schedule
    survives a reboot).
  - A tap opens `/hom-nay` and logs `today_open{source: notification}`.
  - **Off switch:** a row in Sảnh beside "Tự phát lời kể"
    (`_NarrationRow`), with the time picker. Turning it off cancels everything
    pending.
  - Privacy: nothing leaves the device. Re-read the privacy policy page and
    the Play Data safety answers anyway, in case they list permissions.

### D-2c — Content (CMS)

- **Schema and tools:** add `anniversary` to `content/event.schema.json`,
  `content/FIELD-REFERENCE.md`, `ContentValidator`, `HistoryEvent`, and the CMS
  event dialog (`apps/admin/lib/widgets/event_dialog.dart`, next to
  `event_year_field.dart`).
  - **Ship this before any content uses the key** (see "What I measured").
- **The review table** (`docs/anniversaries-review.md`):
  - For the 66 candidate events, list the event, the candidate day and month,
    `solar`/`lunar`, and the sentence and citation that support the date.
  - The user approves each row, the same way as the M3 street review.
  - The rule of thumb is to assume a date is **lunar** unless the source
    says otherwise, for anything dated from the chronicles (pre-20th
    century). Check each date against its source.
- **Out of scope here:** adding new events just to fill empty days. The
  rotation covers them.

### D-2 tests

- `todayPick`:
  - an anniversary day;
  - a lunar anniversary in two different years;
  - a day with no anniversary (rotation);
  - no repeat within a year;
  - an excluded leader is never a rotation pick;
  - determinism.
- The validator accepts and rejects `anniversary` values.
- An **old-build parse** of a pack that carries `anniversary` (a 1.3.0 build
  must still adopt it).
- The `/hom-nay` redirect, for an event and for a person.
- Notification scheduling, behind a fake seam like `QuizStore`: 14 entries
  with the right titles; re-scheduled on pack adoption; all cancelled when
  turned off.

## D-3 — The street map fills in

- **`VisitStore`** (file-backed, the same pattern as the other stores): a set
  of `person:<id>`, `event:<id>` and `era:<slug>`.
  - It is recorded by **one** navigator observer that reuses
    `mapUriToScreen`, so no screen has to remember to record a visit.
  - On first load it is **back-filled from `NarrationPrefs.heard`**, so
    existing users don't start at zero.
- **A street is discovered** when any of its targets is in the store. Pure
  helper and tests are in `core_domain`, next to `StreetMatcher`.
- **On the map** (`street_map_screen.dart`):
  - Undiscovered streets keep today's `_kRestingStreet`.
  - Discovered streets draw in a second, brighter gold in their own
    `PolylineLayer`, cached like `_restingLayer` and keyed by the store's
    identity.
  - **Only two tones** (the rainbow lesson). A new user's map looks exactly
    like today's.
- **The count** (decision 6): one line in the filter sheet's header.
- **The moment it happens:** when a page lights a street for the first time,
  the existing reverse street chip (`street_reverse_chip.dart`) shows
  "Vừa thắp sáng: đường Lý Tự Trọng" once. There's no toast and no sound.
  - "Hôm nay" picks with a street (D-2a) make this happen most days.
- **Speed:** a second polyline layer adds draw work, and the street-map speed
  plan is still open (`docs/wave-e-plan.md`, S0). Use `street_perf.dart` to
  time the map with 0, 50 and all 285 streets discovered before shipping.
- **Tests:**
  - the store and its back-fill;
  - the discovered helper (person, event and era targets);
  - the map widget draws the second layer only for discovered ids;
  - the chip line shows once.

## D-4 — Ship

1. **Release 1 (D-1, plus the D-2c schema and CMS field):** bump the version
   and build the bundles. The user uploads them and records the D-0 baseline
   first.
2. **Content:** the user approves `docs/anniversaries-review.md` and enters the
   rows in the CMS, then publishes (dry run first). Old builds ignore the key.
3. **Release 2 (D-2 app + D-3):** bump and build.
4. **On a phone (Android, and iOS when it ships):**
   - share a daily result into Zalo and Messenger;
   - "Hôm nay" on an anniversary date (set the device date to 30/4 and to a
     lunar test date) and on a plain day;
   - opt in, get a notification, tap it, reboot, and confirm the schedule
     survived;
   - turn it off and confirm nothing arrives;
   - streets light up after reading, and the map stays smooth.
5. Commit on `main` and update this file.

## Next cycles (queued — not to be planned until the user says)

Carried from `a150c78:EXECUTION.md`, not re-checked in this cycle:
- **Wave E content:** foreign friends of Vietnam, scientists, artists,
  writers, classical poets, Tô Hiến Thành, Nguyễn Hữu Cầu, about 84 people,
  plus the street-map speed plan (S0–S5). See `docs/wave-e-plan.md`. Local
  Southern martyrs are still deferred (they need sources).
- **Wave E street mapping over the air:** built 2026-10-05; it needs one app
  release (see R's notes).
- **Wave C/D follow-ups:** dedicated 1:1 avatars for the 49 head-crop people;
  re-check Phạm Bành and Xuân Ôn; the held portraits (Mai Xuân Thưởng, Trần
  Tấn, Đặng Như Mai, Tôn Thất Tiệp, Tôn Thất Đàm, Lý Chính Thắng).
- A landmark object and landmark detail page (Ba Đình, Trường Sơn, Vạn Kiếp…).
- A "Danh nhân" directory for standalone people.
- Hoàng Sa / Trường Sa.
- More landmarks, an in-house lacquer base-map style, streets near me, more
  cities, a CMS editor for street mappings, and the carried-over UX audit
  findings (`21fb88b:EXECUTION.md`).
- **New from Cycle S, not planned:**
  - app links, so a shared result opens the app;
  - an image share card;
  - a weekly "Tuần này năm xưa" digest.
