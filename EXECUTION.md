# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: IDLE — nothing queued.**

Cycle A is fully executed, verified, published and committed to `main`.

- **Image audit (Eras 29–31):** ~24 real archival photos were re-captioned
  from "Minh họa · phong cách sơn mài" to "Ảnh tư liệu" or "Ảnh tư liệu ·
  phục chế màu" (Era 28's lacquer illustrations and one poster-style
  painting in Era 29 kept "Minh họa"). Two mismatched heroes were replaced
  with user-supplied images: the 1930 Party-founding painting (enhanced
  only, no colorization) and a Việt Bắc 1947 base photo (colorized, with a
  strict per-face A/B check across ~20 faces). The 1945 famine photo is now
  credited to Võ An Ninh.
- **Era 32 "Thống nhất đất nước"** extended from 1977 to 1986 with 6 new
  events: joining SEV and the Việt–Xô treaty (1978), the 1980 Constitution,
  Chỉ thị 100 "Khoán 100" (1981), the 5th Party Congress (1982), and the
  1985 price–wage–currency reform.
- **New period "Đổi Mới"** (kicker "Nhìn thẳng vào sự thật") with **Era 35
  "Công cuộc Đổi Mới"** (1986–1995), 9 events: the 6th Congress, the
  Foreign Investment Law, Gạc Ma (14/3/1988), Khoán 10, the first rice
  exports (1989), the 7th Congress, the 1992 Constitution, the US embargo
  lift, and the July 1995 double milestone (US normalization + ASEAN).
- **4 new figures:** Nguyễn Văn Linh, Võ Văn Kiệt, Đỗ Mười, Trần Văn Phương.
  Trần Văn Phương's only known photo was too degraded for two AI
  restoration attempts to reconstruct reliably (both drifted toward a
  generic, idealized face); his portrait uses a plain local upscale
  instead, to avoid risking a fabricated likeness of a named martyr. Worth
  the user's own eyes on this one.
- 35 eras · 212 events total (was 34/197). Territory atlas's "thong-nhat"
  snapshot now also covers Era 35 (the territory is unchanged since 1975).
- **Verified:** all 26 generated/restored images A/B-checked against
  source (1 fallback to local upscale, as above); validate:content 35 eras
  · manifest 0 collisions · analyze clean · 117 tests · web smoke test
  confirmed Era 32's extension, Era 35, and the global timeline count
  (35 kỷ nguyên · 212 sự kiện).
- **Published:** pack `20260924044851` (35 eras, 1228 KB) is live on R2.
- **Higgsfield spend:** 44 of the 120-credit cap for this cycle.
- **6 commits** landed on `main` (2 caption/content fixes, 2 feat content,
  1 territory/test update folded into the Era 35 commit, 1 version bump).

## Still awaiting the user
- **Trần Văn Phương's portrait:** the user should look at it themselves
  and say whether the local-upscale fallback is acceptable, or whether to
  try again, use a different source, or omit the portrait.

## Next cycles (queued, user's order)
1. **Cycle B — the chronicle, 1996 → 2025** (outline; planned in full next):
   - **Era 36, Hội nhập (1996–2007):** Đại hội VIII (1996); APEC membership
     (11/1998); the 1999 Enterprise Law; the US–Việt Nam BTA (13/7/2000);
     SEA Games 22 (12/2003); APEC 2006 in Hà Nội; **WTO, the 150th member**
     (11/1/2007), echoing the UN's 149th. Figures: Phan Văn Khải, Nông Đức
     Mạnh, Trần Đức Lương.
   - **Era 37, Vị thế mới (2008–2019):** Hà Nội expanded (1/8/2008); leaving
     low-income status (verify the World Bank year); Thăng Long's 1000th
     anniversary (10/2010); the 2013 Constitution; HD-981 (5/2014, **user
     decision needed**); CPTPP (2018) and EVFTA (6/2019); UN Security
     Council election (2020–2021 term). Figures: Nguyễn Phú Trọng, Nguyễn
     Tấn Dũng.
   - **Era 38 "Kỷ Nguyên Vươn Mình"** (2020–2025, user-chosen name, slug
     `ky-nguyen-vuon-minh`): COVID-19; Đại hội XIII (2021); General
     Secretary Nguyễn Phú Trọng's death (19/7/2024); Nghị quyết 57
     (12/2024); the 34 provinces/cities from 1/7/2025; the 50th anniversary
     of Reunification (30/4/2025); A80, the 80th National Day (2/9/2025);
     2025 growth (GSO figure, no superlatives without a source). Figures:
     Nguyễn Phú Trọng, **Tô Lâm** (sitting General Secretary — official
     portrait, neutral record-based text only).
2. **Câu đố (quizzes)**, as a new Sảnh row.
3. **UX polish pass**: screen-by-screen audit at phone size, then fixes
   chosen by the user.

## Paused (Play Console)
The user's Play developer account is under review. When approved, resume
at: create the upload keystore → `key.properties` → Claude builds and
verifies the AAB → Play Console setup → `long_ky_tea` → license-tester
purchase test. Full steps are in git history (`80d0117:EXECUTION.md`).
