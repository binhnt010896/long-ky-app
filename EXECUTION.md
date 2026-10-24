# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: Cycle T is PLANNED (2026-10-24), not started.** Nothing is built.
**Waiting on the user:** the decisions in "Decide before building", then the
go-ahead. **Depends on Cycle S** (PR #4, open, not merged): T reuses its visit
store and its daily reminder, so PR #4 merges first.

Earlier specs: Q `84d5ed8`, R `a150c78`, S `28e5f1e` (each `<sha>:EXECUTION.md`).

> Naming: this cycle's parts are **H-0 … H-9** ("hidden"). `S0`–`S5` name the
> street-map speed plan and `D-0`–`D-4` name Cycle S.

## Audit of the previous plan

Cycle S (D-0 to D-3) is built and in PR #4: share the daily quiz, "Hôm nay"
with an opt-in reminder, and a street map that fills in. Everything that was
waiting on the user is still waiting (see `28e5f1e:EXECUTION.md`):
1. The phone check on Android and iOS. The native changes were never built.
2. Approving `docs/anniversaries-review.md`.
3. The Day 1/7/30 retention baseline in Firebase.
4. The version bump, the privacy page and the Play Data safety answers.

## Cycle T — what the user asked for

> I want more user-engaging. For this feature, let's take into account only
> the characters/events of eras before the photographed.
> Let's replace half of the characters' avatar of each era with a anonymous
> avatar (an frame with a general silhouette and a question mark in the middle
> should do it - can use Higgsfield to generate)
> Everyday they will unlock a random avatar/image of a hidden char/even (no
> quiz needed) -> add to streak.
> Add reward animation.
> If they want to unlock more, when they enter a detail character/event page,
> prompt a quiz of an that hidden character/event, if they get it right (which
> we would not trick them, if they choose wrong, make them choose again until
> they get it right), we will reward them with the avatar/image of that
> event/character.
> Create streak and unlock counts so they will likely comeback everyday for more.

**This changes a standing rule.** The app has a "no streaks, no nags" rule:
- `apps/mobile/lib/screens/quiz/quiz_home_screen.dart:15`: "No streaks, badges
  or leaderboards".
- `apps/mobile/lib/state/quiz_store.dart:34`: "No streaks … see the
  delicate-UI rule".
- `[[delicate-ui-no-nags]]`, defined in a CLAUDE.md that is not in this repo.

Cycle T adds a streak because the user asked for one. Two things follow:
- Execution updates those code comments.
- **The user should update the rule in their local CLAUDE.md.** Otherwise a
  later session will follow it and fight this feature.

The streak applies only here. The quiz screen's own modes stay as they are.

## Decide before building

1. **Which half is hidden.** I recommend **fixed by the content**, the same for
   every reader:
   - In each era, sort the people and the events by a stable hash of their id,
     and hide `floor(n/2)` of each.
   - **Never hide the era's first roster person or its first event.** The era
     hub then always opens on a face and a picture, not a wall of question
     marks.
   - The alternative is a different random half per reader. That makes
     screenshots and support confusing, for no gain.
2. **Readers who already saw the art.** I recommend **pre-unlocking every page
   they have already opened.** Cycle S's visit store and narration history
   record these. Taking away a picture someone has seen feels like a loss.
   The alternative is to hide the half for everyone, which is simpler but
   punishes existing readers.
3. **How the daily unlock is offered.** I recommend **a gift the reader taps:**
   - a glowing "Quà hôm nay" chip on Home, next to the seal;
   - the same gift as a card at the top of the Sảnh.
   - The alternative is a sheet that pops up after the splash. It is harder to
     miss but interrupts every launch.
4. **A daily cap on quiz unlocks.** I recommend **3 a day.**
   - The user asked for a re-try until the answer is right, so every quiz on a
     hidden page always ends in an unlock.
   - With no cap, a reader who browses unlocks everything in one sitting. The
     daily gift and the streak then stop mattering.
   - When the cap is reached the page says so: "Hết lượt hôm nay — mai quay
     lại nhé".
5. **What a streak day is, and what a missed day does.**
   - **A streak day:** I recommend counting a day once the reader opens the
     gift *or* unlocks with a quiz.
   - **A missed day:** I recommend **a reset to 0, but with one free "giữ
     chuỗi" (streak freeze) earned every 7 streak days, holding at most 2.**
     It covers one missed day. The alternative, a plain reset, is harsher.
6. **Milestones.** I recommend **one extra unlock at 7, 30 and 100 days**, each
   with the bigger version of the reward animation.
7. **How a page offers its quiz.** I recommend **inline, not a modal:**
   - the hidden image itself shows "Mở khóa", and so does a small prompt under
     it;
   - a tap opens a one-question sheet.
   - A modal on every visit to a hidden page would read as a nag.
8. **The question mark.** I recommend **drawing it in code over the generated
   frame.** Image models often garble text, and a "?" in code is sharp and can
   be animated during the reveal. Higgsfield makes the frame and the
   silhouette only.
9. **What stays visible.** I recommend **only the image is hidden.**
   - The name, epithet, bio, events and narration all stay.
   - Hiding the text would make the quiz unanswerable and the app worse to
     read.

## What I measured (read-only, 2026-10-24)

- **The photograph line already exists.** The portrait audit covers "Hồng
  Bàng to Tự Đức, 26 eras … Cần Vương onward is built from photographs"
  (`docs/portraits-privacy-loops-plan.md:108`).
  - In `content/index.json` that is `hong-bang-van-lang` through `tu-duc`. The
    first photographed era is `can-vuong` (1884–1896).
  - The assets carry no "photo" flag (the "Ảnh tư liệu" caption is not in
    `people.json`), so the rule has to be by era. **Proposed rule:** an era is
    in scope when `yearRange.startYear < 1884`. A new pre-1884 era is then
    included automatically.
- **Scope:** 26 eras.
  - 121 roster slots, which is **115 people**. Six are on two rosters, for
    example `an-duong-vuong` (Hồng Bàng and Âu Lạc) and `y-lan` (two Lý eras).
    A person is hidden or shown by id, not by slot.
  - **140 events**, all with a hero image.
  - **Half per era: 52 people and 64 events, so ~116 hidden images** in all,
    before decisions 1 and 2. The two always-visible items per era reduce this
    a little.
  - **Pacing:** with only the daily gift, ~116 days to unlock everything. With
    3 quiz unlocks a day (decision 4), ~29 days at most.
- **Every hidden item can get a fair question** built from published content.
  This matters because no question text is hand-written (see
  `QuizGenerator`).
  - **All 115 people** have an epithet and appear in at least one event.
  - **Of the 140 events:** 138 have figures (a "who" question), 134 have a pull
    quote, 104 have an exact year, and all can have an "which era" question.
    None is left with just one type.
- **Where these images are drawn.** Each needs the gate, and nothing else
  draws them:
  - `screens/event/widgets/event_figures.dart:124`: the avatar tile. It is used
    by the era hub roster (`era_hub_screen.dart:242`) and by an event's figure
    strip.
  - `screens/character/character_detail_screen.dart:166` and `:174`: the full
    body, or the legacy sheet bust.
  - `screens/event/event_detail_screen.dart:356`: the event hero. Its
    `flagship` may be a looping WebP.
  - **Not in scope:** era covers, scenes and the Home crest
    (`home_screen.dart:502`). The standalone person and event screens are out
    too, since standalone items belong to no era.
- **The prefetcher** warms every avatar, full body and hero of an era
  (`state/media_prefetch.dart:146`). It stays as is, so a reveal is instant.
  The art is on a public CDN anyway; hiding is a game, not protection.
- **Existing patterns to reuse:**
  - `flutter_animate` (already a dependency), `ParticleField` (ambient only; a
    burst needs a new painter) and `HapticFeedback`.
  - The tier capabilities, `MediaQuery.disableAnimations` and the "new" dot on
    the Home seal (`showNew`).
- **A design note in the code:** "the user rejects any framing" of portraits
  (`event_figures.dart:116`, `character_detail_screen.dart:152`). The frame
  here is part of the *mystery* art and shows only while the image is hidden.
  A revealed portrait keeps its frameless look.
- **The character page lists the events the person appears in.** So a "which
  event" question can always be answered from the page the reader is on.

## H-0 — Art (Higgsfield; ~3 images plus re-rolls)

Make **three placeholders, bundled in the app as assets, not on the CDN.**
They then work offline, and old builds never see them.

| Asset | Shape | Replaces |
|---|---|---|
| `assets/mystery/avatar.png` | 1:1, ≥ 1024 px | avatar tiles |
| `assets/mystery/full.png` | 2:3, ≥ 1024 × 1536 | the character page's full body |
| `assets/mystery/hero.png` | the heroes' aspect (**measure a local hero at execution**: the CDN returned 403 to a direct fetch) | the event hero |

- **The brief:**
  - Lacquer-painting style matching the app (deep lacquer red-black, gold
    leaf).
  - A gold frame, and inside it a soft generic silhouette: head and shoulders
    for the avatar, a standing figure for the full body, a faint scene of
    people for the hero.
  - **No face, no clothing that names an era, no text, no question mark.** The
    centre is left calm for the "?" drawn in code (decision 8).
- **Checks:**
  - Reviewed before the user sees it.
  - One generation at a time, never a multi-reference batch (the standing
    Higgsfield rule).
  - Optimised to WebP so the app stays small.

## H-1 — Domain (`packages/core_domain`, pure, tested)

**`hiddenArtKeys(eras)`:** the set of `VisitKey`s whose art starts hidden.
- Eras with `yearRange.startYear < 1884`, per the rules in decision 1.
- A person on two rosters is decided once, by id: they are hidden if their
  first in-scope roster hides them.
- Deterministic: the same content always gives the same set. A content pack
  that adds an event can change the set, but never hides an item a reader has
  already unlocked.

**`QuizGenerator.questionFor(VisitKey)`:** one question about one person or
event, seeded by the id so a revisit gets the same question.
- **An event:** today's year, who, quote and era builders, restricted to that
  event, preferring a type answerable from the event page.
- **A person, three new generated types (no hand-written text):**
  - **event:** "X gắn với sự kiện nào?", with the right event from the person's
    events and distractors from other eras;
  - **era:** "X sống vào thời nào?";
  - **epithet:** "Ai được gọi là «…»?".
- Post-1975 leaders are out of scope by era already.

**`Streak.advance(lastDay, today, freezes)`:** day arithmetic on calendar dates,
not hours, so midnight and DST can't break it.
- Tests: across a month end and a year end; a missed day with and without a
  freeze; two days missed; and the clock set back, which never increases the
  streak.

**`dailyGiftPick(remaining, date, installSeed)`:** a random pick from what is
still hidden. It is stable for the whole day, so reopening the app shows the
same gift.

## H-2 — State (`apps/mobile/lib/state/unlock_store.dart`)

`unlocks.json` holds:
- the `unlocked` keys;
- `giftDate` (the gift claimed today) and today's `giftKey`;
- the streak: `current`, `best`, `lastDay`, `freezes`;
- the day's quiz unlocks: `quizDay` and `quizCount`.

Same file pattern as the other small stores (atomic write, defaults on a bad
file).
- **First run:** pre-unlock pages already opened (decision 2), from
  `visitedProvider` (Cycle S) and `NarrationPrefs.heard`. This runs once and
  is marked done.
- **Device-only progress.** Reinstalling or changing phones loses it, because
  there are no accounts and Firestore is off. Say so on the counts screen.
  Cloud backup is a later cycle.
- **Changing the phone's date** can game it. Accepted: this is a game played
  alone.

## H-3 — The gate (one widget, every image)

`ArtGate(key: VisitKey, child: <the real image>, mystery: avatar|full|hero)`:
- **While hidden:** the mystery asset, a "?" in the app's display face, and a
  "Mở khóa" affordance.
- **Once unlocked:** the real image, with no frame.

It is used at exactly the three places measured above. Widget tests cover each
place in both states, and check that a revealed portrait keeps no frame.

## H-4 — The daily gift

- **Entry points:**
  - **Home:** a "Quà hôm nay" chip by the seal, glowing until opened today
    (decision 3).
  - **Sảnh:** a card under "Hôm nay" with the counts (H-7).
- **Opening it:**
  - the reveal (H-6) of today's `dailyGiftPick`;
  - then "Xem trang" goes to that person's or event's page;
  - the day counts toward the streak (decision 5).
- **Once everything is unlocked:**
  - the gift becomes a congratulation;
  - the streak then counts on opening "Hôm nay" (Cycle S), so it never dead-
    ends.
- **With the Cycle S reminder:** the notification body gets "· Quà hôm nay đang
  chờ bạn". The 14 days are scheduled ahead, so the text can't know whether the
  gift was opened; it stays generic. **No extra "streak at risk"
  notification:** that would be a second daily ping. Revisit it once there are
  numbers.

## H-5 — Unlocking from a page

On a hidden person or event page, the gated image and a small line under it
offer "Trả lời một câu để mở khóa ảnh" (decision 7). A tap opens a sheet with
`questionFor(key)`.

- **A wrong answer:**
  - the option is marked and disabled, with a soft shake and haptic, and
    "Chưa đúng — thử lại nhé";
  - **no penalty, no lost turn;** the reader picks again until it is right.
- **The right answer:**
  - the sheet closes;
  - the image reveals in place (H-6);
  - the counts and today's quiz count go up, and the day counts for the
    streak.
- **The cap (decision 4):** once reached, the sheet does not open. The line
  reads "Hết lượt mở khóa hôm nay — mai quay lại nhé" and shows the streak.
- **After the answer:** the question's citation line, the same one the quiz
  screen shows, so the reader learns where it comes from.

## H-6 — The reward animation

About 1.2 s, and **a tap skips it.**
1. The mystery frame trembles, and the "?" brightens and lifts away.
2. A gold light sweeps across, the frame dissolves, and the real image scales
   from 0.92 to 1 and fades in.
3. A burst of gold motes from the centre (a new burst painter beside
   `ParticleField`), with a medium haptic.
4. "+1 · 35/116" ticks up, and the streak flame bumps once if this was the
   day's first unlock.

- **The milestone version (7/30/100 days):** a longer burst and a line such as
  "Chuỗi 7 ngày! Thêm một lượt mở khóa".
- **The reduced tier, or `disableAnimations` on:** a plain 300 ms crossfade and
  the count, with no particles or shake.
- **No sound.** Narration owns the audio, and a sound per unlock would grate.

## H-7 — Counts and streak

- **The Sảnh card:**
  - "Đã mở 34/116 · Chuỗi 5 ngày 🔥 · 1 lượt giữ chuỗi";
  - per period, it can expand to "Nhà Trần 3/6".
- **The era hub roster header:** "3/6 chân dung · 2/6 tranh sự kiện", for eras
  in scope only.
- **The Home chip:** shows the streak once today's gift is opened.
- **A lost streak** is stated calmly, once: "Chuỗi đã bắt đầu lại — hôm nay là
  ngày 1". The best streak is kept and shown.
- **Code comments:** update the "no streaks" ones in `quiz_home_screen.dart` and
  `quiz_store.dart` to say the streak lives in the unlock feature, by the
  user's decision of 2026-10-24.

## H-8 — Measurement

New events, added to the taxonomy and `telemetry_test.dart`:
- `gift_open` `{streak}`;
- `unlock` `{source: gift|quiz|milestone, kind: person|event, attempts}`
  (attempts = taps until right);
- `unlock_cap_hit`;
- `streak_reset` `{lost, used_freeze}`;
- `streak_milestone` `{days}`.

Analytics is Android-only, so compare Day 1/7/30 retention against the Cycle S
baseline there.

## H-9 — Tests and ship

- **Tests:**
  - **Domain:** the hidden set (both always-visible rules, the shared person,
    determinism), every question type for every in-scope item (a test loops
    over the real content: 115 people and 140 events must each get a
    question), streak arithmetic, the gift pick.
  - **State:** the pre-unlock migration, the cap, and a bad file.
  - **Widgets:** the gate at all three places; a wrong answer allowing a
    re-try until right; the reveal in both tiers; the counts.
- **Ship:**
  - **App release only.** No content change, assets bundled.
  - **Old builds** see no change.
  - **Order:** merge PR #4, then build T.
- **On a phone:**
  - first launch for a new reader, and for one with history (pre-unlock);
  - the gift and its animation;
  - a wrong-then-right quiz;
  - the cap;
  - change the date to test a missed day, the freeze and the reset;
  - the reduced tier.

## Risks to weigh

- **The first impression gets darker.** Half the old portraits become question
  marks on a new reader's first visit. Decision 1's always-visible lead
  figure, plus a first gift on day one, soften this. Watch Day 1 retention.
- **A streak brings loss aversion,** which is exactly what the old rule
  avoided. The freeze and the calm reset message limit the sting. If Day 30
  retention does not move, remove the streak and keep the unlocks.
- **Never sell unlocks.** Charging money for random unlocks would put the app
  under app-store loot-box rules and break the donations-only stance. This
  plan has no purchase anywhere.

## Next cycles (queued — not to be planned until the user says)

- Everything queued in `28e5f1e:EXECUTION.md`: Waves C/D follow-ups, Wave E,
  the landmark page, "Danh nhân", Hoàng Sa / Trường Sa, more streets.
- From Cycle S: app links for shared results, an image share card, a weekly
  digest.
- From T: cloud backup of progress (needs accounts), a "collection" screen of
  every unlocked portrait, the streak-at-risk reminder (if the numbers ask for
  it), extending the hiding to the photographed eras (it would need different
  art: no silhouette may imply a photographed face).
