# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: IDLE — nothing queued.**

Cycle C (UX polish, the confirmed subset) is fully executed, verified,
published and committed to `main`.

- **Removed the "Chào cờ hôm nay" pill from Home.** The user called it
  "abundant, and not delicate," reversing an earlier "always show it"
  decision. Chào cờ stays reachable only through its existing Sảnh card.
  Also removed: the now-unused `todayProvider`/`nationalDayOn` helpers, and
  the two pill-specific tests (replaced by one asserting its absence).
- **Home's era indicator no longer overlaps the subtitle.** Per the user's
  preferred approach, the kicker/title/subtitle block moved up (wider bottom
  inset) rather than pushing the gold indicator down.
- **The territory atlas's timeline scrubber now reads "1977 – nay"** for its
  final snapshot, instead of a bare "1977" that undersold how much of the
  chronicle it covers. The current-year pill is sized to its text so this
  longer label — and any other multi-word label — never wraps to two lines;
  the redundant axis label under the selected thumb was also dropped, since
  the pill already names it.
- **Three Cycle B misses, found and fixed while auditing:**
  - **Trần Đức Lương died 20/5/2025** (source: baochinhphu.vn); his bio said
    only "sinh 1937". Corrected to "(1937–2025)".
  - **Võ Văn Kiệt was missing from Era 36's figures**; added by reference.
  - **The Nghị quyết 57 illustration had a glossy canvas bevel** across its
    top edge (the panel/frame failure mode). Found by a corner check of all
    7 Cycle B generated images — the other 6 were clean. Regenerated with a
    stronger anti-panel prompt and re-checked before placing.
- **On the Era 38/period accent color:** raised as a possible mismatch with
  Đổi Mới's dot on Home's period rail; the user said Era 38 looks fine as
  encountered, so this was dropped — no color change made.
- **Verified:** `validate_content` 38/38 · manifest 0 collisions (same 2
  pre-existing missing hai-ba-trung files) · `analyze` clean · 118/118 tests
  passing (2 removed, 1 replacement + 2 new `TimelineBar` tests) · web smoke
  test at 375×812 confirmed all of the above live.
- **Published:** pack `20260924105328` (38 eras, 1299 KB) is live on R2.
- **3 commits** landed on `main` (1 `refactor!` for the pill removal, 1 `fix`
  for the atlas label/pill, 1 `fix(content)` for the three Cycle B misses).

## Carried over — not decided this round

These audit findings from the last planning cycle were never confirmed or
declined; they're parked here rather than silently dropped.

| id | finding |
|---|---|
| G1 | Floating top bars (era hub, event detail, era timeline) have no scrim; content scrolls under them. |
| G2 | Gold particle motes drift over reading text. |
| G3 | Figure tile names truncate to one line. |
| H2 | The period rail now has 17 dots and runs long. |
| E1 | *(needs a device check)* Empty band on the era hub, above the overview. |
| EV1 | Event titles can leave a one-word orphan line. |
| EV2 | The swipe-hint on Event Detail floats over the Nhân vật row until dismissed. |
| C1 | *(needs a device check)* Empty gap on Figure Detail, above the bio. |
| S1 | The Sảnh footer shows a raw build id instead of a date. |
| CC1 | Chào cờ's lyrics are hard to read over the busy ceremony photo. |
| M3 | The atlas map sits in a band with large empty space above/below at phone height. |

## Next cycles (queued)
1. **Câu đố (quizzes)**, as a new Sảnh row.
2. Revisit the carried-over findings above, if wanted.

## Paused (Play Console)
The user's Play developer account is under review. When approved, resume
at: create the upload keystore → `key.properties` → Claude builds and
verifies the AAB → Play Console setup → `long_ky_tea` → license-tester
purchase test. Full steps are in git history (`80d0117:EXECUTION.md`).
