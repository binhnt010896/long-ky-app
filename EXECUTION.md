# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: IDLE — nothing queued.**

Cycle B is fully executed, verified, published and committed to `main`.

- **Trần Văn Phương's portrait, redone.** The plain local-upscale fallback
  from Cycle A is replaced by a Higgsfield restoration (autocontrast +
  upscale reference, a black-and-white-only restore naming the facial
  traits to keep, then a separate colorize-only pass), A/B-checked against
  the source photo.
- **Three new eras, closing the chronicle at 12/2025:**
  - **Era 36 "Hội nhập quốc tế" (1996–2007),** 8 events: Đại hội VIII,
    joining APEC (1998), the Enterprise Law (1999), the China land-border
    treaty and Gulf of Tonkin delimitation, the Vietnam–US trade
    agreement (2000), SEA Games 22 (2003), APEC 2006, and WTO accession as
    the **150th member** (2007), echoing the UN's 149th (Era 32).
  - **Era 37 "Vị thế mới" (2008–2019),** 7 events: Hà Nội's expansion
    (2008), leaving low-income status (2008–2010), the 1000th anniversary
    of Thăng Long (2010), the 2013 Constitution, APEC 2017, CPTPP/EVFTA,
    and the UN Security Council seat (2019).
  - **Era 38 "Kỷ nguyên vươn mình" (2020–2025),** 10 events: COVID-19, the
    ASEAN chair year and RCEP (2020), Đại hội XIII (2021), "bamboo
    diplomacy" and the US Comprehensive Strategic Partnership (2023),
    Nguyễn Phú Trọng's death and Tô Lâm's succession (2024), Nghị quyết 57
    (2024), the 50th reunification anniversary (30/4/2025), the 34-province
    restructuring (2025), A80 (2/9/2025), and 2025 growth (NSO, +8.02%).
  - Đại hội IX and XI were folded into their era overviews rather than
    given standalone event cards, per the user's "history, not politics"
    restraint; HD-981 was excluded per the user's decision.
- **New period "Kỷ nguyên mới"** (2020–2025, kicker "Là bạn, là đối tác
  tin cậy") carries Era 38; "Đổi Mới" now runs 1986–2019.
- **9 new figures:** Lê Khả Phiêu, Trần Đức Lương, Phan Văn Khải, Nông Đức
  Mạnh, Nguyễn Tấn Dũng, Nguyễn Phú Trọng, Tô Lâm, Phạm Minh Chính, Lương
  Cường. Đỗ Mười and Võ Văn Kiệt are reused by reference. All portraits are
  real photos the user supplied — every one already in color, so each was
  locally enhanced/upscaled only (no colorization needed). Sitting/former
  leadership was checked live against vietnam.gov.vn during planning
  (Phạm Minh Chính and Lương Cường had by then finished their terms, so
  both got full figure cards rather than office-only mentions).
- **Higgsfield generation:** the one B&W event photo (Đại hội VIII) was
  colorized and A/B-checked against the source; 3 era covers, 1 period
  cover, and 3 event illustrations with no identifiable people (Luật
  Doanh nghiệp 1999, Nghị quyết 57, tăng trưởng 2025) were generated. One
  era-38 cover attempt was rejected and regenerated for violating the
  full-bleed/no-frame rule.
- 38 eras · 237 events · 17 periods total (was 35/212/16). Territory
  atlas's "thong-nhat" snapshot now also covers eras 36–38 (fetched a
  fresh Natural Earth basemap this session; the territory itself is
  unchanged since 1975).
- **Verified:** `validate_content` 38/38 eras · manifest 0 collisions (2
  pre-existing missing hai-ba-trung ridge files, expected) · `analyze`
  clean · 117/117 tests passing · web smoke test confirmed the 3 new eras,
  the new period, and the "38 kỷ nguyên · 237 sự kiện" count.
- **Published:** pack `20260924094323` (38 eras, 1299 KB) is live on R2.
- **3 commits** landed on `main` (1 feat content, 1 chore version bump, and
  this docs reset).

## Next cycles (queued, user's order)
1. **Câu đố (quizzes)**, as a new Sảnh row.
2. **UX polish pass**: screen-by-screen audit at phone size, then fixes
   chosen by the user.

## Paused (Play Console)
The user's Play developer account is under review. When approved, resume
at: create the upload keystore → `key.properties` → Claude builds and
verifies the AAB → Play Console setup → `long_ky_tea` → license-tester
purchase test. Full steps are in git history (`80d0117:EXECUTION.md`).
