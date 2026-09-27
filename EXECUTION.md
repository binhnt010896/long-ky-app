# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: Cycle J shipped. Decisions: J1 yes, J2 yes, J3 yes, J4 yes.**

- **J-1 Home follows the language.** Three hard-coded `Lang.vi` spots (era
  hero, dynasty title, dynasty years) now read `langProvider`; `KHÁM PHÁ` /
  `ĐỈNH CAO` translate too (both on Home and the global timeline). The choice
  now **persists** across launches via a new `FileLangStore`
  (`lib/state/lang_store.dart`, same on-disk pattern as the telemetry
  setting), read in `main.dart` before the first frame and saved on every
  `LangToggle` tap.
- **J-2 Atlas in English.** `AtlasRegion`/`AtlasSnapshot` moved from `String`
  to `LocalizedText`. A new `tool/geo/atlas_i18n.py` holds the VI→EN table
  (109 unique labels) and a `translate()` that raises on anything missing —
  wired into both `gen_atlas.py` (for a future regeneration) and a one-off
  `tool/geo/patch_atlas_i18n.py` that rewrote the already-generated
  `territory_atlas_data.dart` in place (the ne10m source + `shapely` aren't
  available in this environment, so a full regeneration wasn't possible this
  cycle — geometry is untouched either way). Vietnamese polities keep their
  Vietnamese name; foreign dynasties/polities translate (Nhà Thanh → The Qing
  Dynasty); Hoàng Sa/Trường Sa keep their Vietnamese names in English too,
  never "Paracel"/"Spratly". `TimelineBar` prints BCE in English.
- **J-3 Readable event list.** `era_timeline_screen.dart`'s scrim: 0.1 → 0.22;
  each card's fill: `inkPrimary@3–7%` → `lacquer@82–90%`. Measured (not
  eyeballed) against the brightest era scene stop across all eras
  (`gia-long`, luminance ≈0.72, RGB 240/220/160): contrast reaches **~5.3:1**
  (inactive card) and **~5.8:1** (active card), both clearing WCAG AA's
  4.5:1 with margin. Verified live in the browser on `gia-long`'s timeline.
- **J-4 Period navigation on Home.** `KHÁM PHÁ`/arrow now
  `animateToPage(i + 1)`s Home, and is hidden entirely on the last period
  (`_DynastyPage.onExploreNext == null`). The right-edge dot rail
  (`_PeriodRail`) is now a live iPhone-Contacts-style scrubber: a drag maps
  finger position to a period index, `jumpToPage`s Home immediately, ticks
  `HapticFeedback.selectionClick()` per new index, swells the dots, and
  floats a `_PeriodBubble` (crest colour, name, years) beside the finger.
  Prefetch is suppressed during the drag and queued once on release, not per
  crossed period. A tap (a drag with no movement) jumps straight to the
  tapped period. The touch strip is sized to the dots' own content height,
  not the full screen, so it doesn't reach into the top chrome (this caught
  a real bug: the first pass covered the Sảnh seal button, breaking its
  tests).
- **Tests:** 5 new files/additions — `lang_store_test.dart` (5),
  `territory_atlas_i18n_test.dart` (6), `home_screen_test.dart` (+5, language
  + scrubber + KHÁM PHÁ), `timeline_bar_test.dart` (+2, BCE/present).
  `melos analyze` and every package's full suite are green: mobile 146,
  core_domain 35.
- **Browser (Flutter web):** verified live — Home in EN (hero, chrome,
  EXPLORE), EXPLORE animating to the next period and disappearing on the
  last, the Atlas in EN (header, hint, China/present-day-border labels,
  Hoàng Sa/Trường Sa kept Vietnamese, BCE), the event list on `gia-long`
  (brightest scene) reading clearly, and a rail drag landing precisely on
  the dragged-to period (both a full top→bottom scrub and a mid-rail
  scrub).
- **Release:** version bumped to **1.0.2+4**. Not yet built or uploaded —
  the user runs `flutter build appbundle --release` (keystore stays with
  them) and uploads to the closed-testing track.

## Audit of the previous plan (before adding — nothing added this cycle)

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
1. **Play closed test (gates production):** get at least 12 testers opted in
   and keep them opted in for 14 days in a row. Aim for about 15. Ask
   testers to install the app and open it a few times, because the
   production application asks about engagement.
   - 1.0.1+3 was never uploaded; **1.0.2+4** (this cycle) is the first real
     upload.
2. Firebase console → Analytics → Custom definitions: register `era_slug`,
   `event_id`, `figure_id`.
3. Deploy the privacy page. Make Play's Data safety form match
   `docs/play-store/data-safety-and-listing.md`.
4. From Cycle E: the `long_ky_tea*` products, license testing, a test
   purchase, screenshots and the feature graphic.
5. Optional: delete the unused Hosting site `admin-long-ky.web.app`.
6. **New from J:** confirm on a real phone that the drag scrubber feels
   right (haptics, bubble legibility, one-handed reach at the screen's
   right edge) — the browser check above can't test haptics or a real touch
   gesture.

**Known caveat, not a task:** an era with `draft: true` is kept out of
over-the-air packs but would still ship in a fresh mobile *build*. No era is
a draft today.

**Known gap, not urgent:** the territory atlas's English strings were added
by patching the generated Dart file directly (`patch_atlas_i18n.py`),
because this environment doesn't have the Natural Earth 10m source file or
`shapely` installed. `gen_atlas.py` itself was updated to emit
`LocalizedText` too, so a *future* regeneration (adding/editing a snapshot,
say) will produce the same shape correctly — it just couldn't be exercised
this cycle. If a real regeneration is needed later, run `gen_atlas.py`
first, not the patch script.

## Next cycles (queued)

Carried-over UX audit findings (top-bar scrims, particles over text, Chào
cờ lyrics legibility, swipe-hint timing) are still parked — see
`21fb88b:EXECUTION.md`. The J-3 scrim/card work likely resolves the
"top-bar scrims" item; re-check it next cycle before re-proposing it.
