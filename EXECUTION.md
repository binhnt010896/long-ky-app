# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: Cycle J planned, not started. Waiting on decisions J1–J4.**

## Audit of the previous plan (before adding Cycle J)

**Cycle I is fully shipped.**
- CMS inline media (I-0…I-3): `9ca27d1`, deployed to `long-ky-admin.web.app`.
- The 17 legacy people have dedicated avatar/full-body art (I-4): `854d683`,
  `7ef2710`, `84b93c5`.
  - Published in run
    [36326346024](https://github.com/binhnt010896/long-ky-app/actions/runs/36326346024),
    content pack `37194fb` (2026-09-27T14:44:10Z).
  - No one in `people.json` uses `portrait` any more.
- Still open from I: the user checks on Android that the 17 figures show the
  new art.

**Still open, in the user's hands:**
1. **Play closed test (new, it gates production):** get at least 12 testers
   opted in and keep them opted in for 14 days in a row. Aim for about 15, so
   one person dropping out doesn't reset the clock. Ask testers to install
   the app and open it a few times, because the production application asks
   about engagement.
   - 1.0.1+3 is already on the closed track, so Cycle J ships as a **new
     build, 1.0.2+4**.
2. Firebase console → Analytics → Custom definitions: register `era_slug`,
   `event_id`, `figure_id`.
3. Deploy the privacy page. Make Play's Data safety form match
   `docs/play-store/data-safety-and-listing.md`.
4. From Cycle E: the `long_ky_tea*` products, license testing, a test
   purchase, screenshots and the feature graphic.
5. Optional: delete the unused Hosting site `admin-long-ky.web.app`.

**Known caveat, not a task:** an era with `draft: true` is kept out of
over-the-air packs but would still ship in a fresh mobile *build*. No era is
a draft today.

## The feedback (from the user's own testing)

1. Switching to English in the Sảnh leaves **Home** in Vietnamese.
2. The **era event list** is hard to read because the background is too
   bright.
3. The **Atlas** is always in Vietnamese.
4. Getting from the first period to the last on Home takes too long. The user
   wants something like the iPhone Contacts index: **grab the side indicator
   and drag** to scrub through periods.

## Facts Cycle J is built on (checked, not assumed)

- **Language state:** `langProvider` is a plain
  `StateProvider<Lang>((_) => Lang.vi)` in `lib/state/providers.dart:55`.
  - It is **not saved**, so every relaunch starts in Vietnamese even after
    choosing EN.
  - The toggle (`LangToggle`) lives in the Sảnh. Era Hub, Timeline, Event,
    Character, Quiz and Global timeline already read `langProvider`.
- **Home ignores the language entirely** (`home_screen.dart`, `era_scene_view.dart`):
  - Three hard-coded `Lang.vi`: the era hero (`EraSceneView(lang: Lang.vi)`,
    line 214) and the dynasty title and years in the top chrome (lines 298,
    305).
  - Hard-coded labels: `'KHÁM PHÁ'` (explore affordance), `'ĐỈNH CAO'`
    (flagship badge, also in `global_timeline_screen.dart:719`), and the
    `'No dynasties'` error.
  - The content is ready: all 17 periods and every era already carry `en`
    titles, subtitles and year displays.
- **Other hard-coded UI strings found in a sweep:**
  - `TimelineBar` always prints `"500 TCN"`, never `BCE` (`timeline_bar.dart:43`).
  - `SealButton`'s semantics label `'Sảnh Long Ký'`, and the splash
    kicker `'NGHÌN NĂM SỬ VIỆT'`.
    - The splash is shown before the saved language could be read, so it
      stays Vietnamese (brand moment).
  - **The Chào cờ anthem lyrics stay Vietnamese by design.** It's the
    national anthem.
- **Era event list** (`era_timeline_screen.dart`, `timeline_event_card.dart`):
  - The backdrop is the era's scene with `scrim: 0.1`, a 10% dark veil.
  - Each card's fill is `inkPrimary` at **3% alpha**, so the card is
    essentially transparent.
  - The text is light (cream), so on bright dawn skies the summary line has
    almost no contrast.
  - For comparison: Home uses a flat 50% black plus a gradient scrim, and
    Character detail uses a 0.4 scrim.
- **Atlas** (`screens/prototype/territory_map_demo_screen.dart`, data in
  `territory_atlas_data.dart`):
  - The data is **generated** by `tool/geo/gen_atlas.py`: 26 snapshots, about
    130 unique Vietnamese-only strings (region names, subtitles, snapshot
    titles, the two boundary labels).
  - `AtlasRegion` and `AtlasSnapshot` hold plain `String`s with no English
    slot.
  - Screen chrome is hard-coded:
    - The header `'BẢN ĐỒ LÃNH THỔ'` and the two-line hint.
    - `'Ranh giới ngày nay'`.
    - The four island labels and subtitles (Phú Quốc, Côn Đảo, Hoàng Sa,
      Trường Sa).
  - `territory_map.dart:471` appends `' (bảo hộ)'` to protectorate names.
- **Home period rail** (`_SideDots` in `home_screen.dart`):
  - 17 periods. The rail is 17 dots, 6 px wide, about 262 px tall, and
    16 px from the right edge.
  - It is **display-only**: no gestures, and it can't be tapped or dragged.
  - Moving between periods is one vertical swipe per page, so the first to
    the last takes 16 swipes.
  - A page change already updates `hubDynastyIndexProvider` and queues
    `MediaPrefetcher` for the neighbouring pages.

## Decisions needed

- **J1 — Remember the language across launches?** *Recommend: yes.*
  - Save the choice to a small file in the app-support folder, the same
    pattern as `FileTelemetrySettingsStore`. No new package needed.
  - Read it at startup, so Home opens in the chosen language.
  - First launch stays **VI**, because Vietnamese is canonical.
    - Alternative: default to EN when the phone's locale isn't Vietnamese.
      Not recommended: the app is for Vietnamese readers first, and EN is
      opt-in.
- **J2 — How names read on the English atlas.** *Recommend:*
  - **Vietnamese polities keep their Vietnamese names, with diacritics**
    (Văn Lang, Đại Việt, Nam Việt, Đàng Trong). The English content already
    works this way.
  - **Foreign polities get their English names:**
    - Han / Ming / Qing dynasty.
    - Champa, Chenla, Siam, Burma.
    - Laos (for Ai Lao), Cambodia.
  - **Hoàng Sa and Trường Sa keep their Vietnamese names in English too**,
    with the subtitle "Archipelago of Vietnam".
    - Never "Paracel" or "Spratly" as the label on its own. This keeps the
      atlas aligned with the Vietnamese government's point of view
      ([[modern-era-sourcing-gov-pov]]).
  - `TCN` becomes `BCE` on the atlas and every timeline bar.
- **J3 — How to make the event list readable.** *Recommend: a darker veil
  plus lacquer cards.*
  - Raise the scrim from 0.1 to about **0.45**, and give each card a dark
    lacquer fill of about **55%** alpha.
  - The scene still shows around and between the cards.
  - **Target:** the summary text reaches **4.5:1 contrast (WCAG AA)** over
    the brightest era scene, measured, not eyeballed.
  - Alternative: frosted-glass blur behind each card. It looks lovely, but
    real-time blur on a scrolling list is expensive on low-tier phones. Not
    recommended.
- **J4 — How the period scrubber behaves.** *Recommend: live, like iPhone
  Contacts.*
  - Dragging along the rail moves Home to that period **immediately**.
  - A small bubble next to your finger shows the period's name and years in
    the current language.
  - A light haptic tick at each period.
  - Tapping a dot jumps straight to it.
  - Alternative: show only the bubble while dragging and move on release.
    Cheaper, but it doesn't feel like Contacts.

## Cycle J — spec

### J-1 Home follows the language (feedback 1, J1)

- Home reads `langProvider`:
  - Pass it to `EraSceneView` (era kicker, title, years, subtitle).
  - Dynasty title and years in the top chrome.
  - `KHÁM PHÁ` / **EXPLORE** and `ĐỈNH CAO` / **PEAK** (in both places).
  - The empty-state message.
- **Save the language** (J1):
  - Add a `LangStore` (file in app support) that writes on every toggle.
  - `main.dart` reads it before the first frame and overrides
    `langProvider`'s initial value, so nothing flashes Vietnamese first.
- **Sweep:**
  - `TimelineBar` prints `BCE` in EN.
  - `SealButton`'s semantics label reads "Long Ký hall" in EN.
- No language toggle is added to Home. It stays in the Sảnh
  ([[delicate-ui-no-nags]]).

### J-2 Readable event list (feedback 2, J3)

- `era_timeline_screen.dart`: `scrim: 0.1` becomes about `0.45`.
- `timeline_event_card.dart`: the card fill changes from `inkPrimary @ 3%` to
  `lacquer @ ~55%`, and the hairline border rises slightly so card edges
  still read.
  - The summary text colour goes up one step if the contrast target isn't
    met.
- **Measure, then tune:**
  - For every era, sample the brightest region of its scene (sky layer)
    behind the list area.
  - Composite the scrim and card fill over it, and compute contrast against
    the summary text colour.
  - Tune the two alphas to the lowest values that pass **4.5:1** on the
    worst era, so the art is dimmed no more than needed.
  - The measured numbers go into this file.
- Nothing else on the page changes (spine, progress bar, animations).

### J-3 Atlas in English (feedback 3, J2)

- **Data:**
  - `gen_atlas.py` gains English for every region (`name_en`, `sub_en`),
    snapshot (`title_en`, `sub_en`) and boundary label.
  - **The generator fails if any English string is missing**, so a future
    snapshot can't ship Vietnamese-only.
  - Regenerate `territory_atlas_data.dart`. The geometry is unchanged: same
    source, same seed.
- **Model:**
  - `AtlasRegion` and `AtlasSnapshot` carry `LocalizedText` (from
    `core_domain`) instead of `String`.
  - The screen resolves them with `langProvider` before building
    `TerritoryRegion`s.
- **Screen chrome:**
  - Header: `BẢN ĐỒ LÃNH THỔ` / **TERRITORY ATLAS**.
  - The hint line.
  - `Ranh giới ngày nay` / **Present-day border**.
  - The four islands' names and subtitles.
  - `(bảo hộ)` / **(protectorate)**, passed into `TerritoryMap` as a label so
    the widget itself holds no language.
- **Translation rules:** as in J2, following the chronicle's own naming
  ([[stay-close-to-dvsktt]]). English is written by Claude. The user reviews
  the full VI → EN table (about 130 rows) before it's merged.

### J-4 Period scrubber on Home (feedback 4, J4)

- The rail keeps its delicate look at rest: the same dots and gold pill, no
  new always-on chrome.
- **Touch target:**
  - An invisible 44 px-wide strip over the rail, slightly taller than it.
  - It sits inset from the screen edge so it doesn't fight Android's
    edge-swipe back gesture.
- **While dragging:**
  - The finger's vertical position maps to a period index across the rail
    height.
  - On each index change: `jumpToPage` (no animation), a haptic
    `selectionClick`, and update `hubDynastyIndexProvider`.
  - Changes are throttled so a fast fling across all 17 doesn't decode 17
    scenes in a burst.
  - The dots swell slightly.
  - A **bubble** floats left of the finger with the period's crest, name
    and years in the current language. It's gold-bordered lacquer and
    matches the app.
- **On release:** the bubble fades out.
  - `MediaPrefetcher` is queued once for the final period only, not for
    every period passed over.
  - The existing `era_card_view` telemetry is already debounced, so a scrub
    counts only where you stop.
- **Tap a dot:** jump to that period.
- **Swiping between pages still works** exactly as today.
- **Accessibility:** the rail is a `Semantics` slider: "Period 5 of 17, Nhà
  Lý", with increase/decrease actions.

### J-5 Verify and ship

- **Tests:**
  - Home renders EN titles, years and `EXPLORE` when `langProvider` is EN.
  - `LangStore` round-trips and survives a missing or corrupt file.
  - `TimelineBar` prints BCE / TCN correctly.
  - Every atlas region and snapshot has non-empty VI and EN.
  - The atlas header and island labels follow the language.
  - Scrubber: a drag at y maps to the right index, and ends on the right
    page. Tapping a dot jumps. Prefetch is queued once on release.
  - `melos analyze` and every suite stay green.
- **Contrast:** the J-2 measurement is recorded, with the worst era and its
  ratio.
- **Browser (Flutter web, cache-busted):**
  - Claude checks Home in EN, the event list on the brightest era, the atlas
    in EN, and a scrub from the first period to the last.
  - This session's Browser pane has shown stale renders before, so the
    final look is the user's call on Android.
- **Release:**
  - Bump to **1.0.2+4**.
  - The user builds the AAB (`flutter build appbundle --release`; the
    keystore stays with the user) and uploads it to the **closed testing**
    track.
  - Uploading new builds during the 14-day test is normal.
- **Order:** J-1 → J-2 → J-3 → J-4 → J-5. J-1 and J-2 are small and could go
  to testers first if the user wants.

### Out of scope for J

- Translating the Chào cờ anthem lyrics (they stay Vietnamese).
- A language toggle on Home.
- Following the phone's locale on first launch (per J1).
- Any content change. This cycle is app code only, delivered by the new
  build, not over the air.

## Next cycles (queued)

Carried-over UX audit findings (top-bar scrims, particles over text, Chào
cờ lyrics legibility, swipe-hint timing) are still parked — see
`21fb88b:EXECUTION.md`. The J-2 scrim work may resolve part of the
"top-bar scrims" item; re-check it after J ships.
