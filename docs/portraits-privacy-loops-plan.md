# Plan: privacy page, the two still "videos", portrait audit, Thánh Gióng, Trần Hưng Đạo

Planned 2026-10-13. **Nothing here is built.** The only work done is the
read-only checking that the plan rests on (the video measurement and the
portrait audit). Side-by-side sheets for every portrait pair are in
`docs/drafts/portrait-audit-2026-10-13/` (30 images, not committed).

## What was asked

1. Move the privacy policy from `binh-nt.dev/long-ky/privacy` to the landing site.
2. `dragon.mp4` and `nha-tran.mp4` have no movement. Why have them?
3. Check every era before the photographed ones: does each avatar match its
   full body? Regenerate where it does not.
4. Redo the Thánh Gióng full body: armour, an iron horse breathing fire, a
   clump of bamboo in his hand.
5. Trần Hưng Đạo's full body is barefoot. Give him footwear.

---

## 1. Privacy policy → `long-ky.com/privacy`

### What I found

- The live page is part of your portfolio app (`~/Projects/portfolio`,
  `lib/screens/legal/long_ky_privacy_screen.dart`). It is a Flutter web page,
  so its text is not in the HTML.
- **It is out of date.** It is dated 26/09/2026 and has 8 clauses. The repo's
  `docs/play-store/privacy-policy.md` has had a 9th clause since 6 October
  (the "Báo sai sót" emails).
- Its contact address is your personal one, not `help@long-ky.com`.
- The app opens this address from **About Long Ký**
  (`kPrivacyPolicyUri` in `apps/mobile/lib/screens/sanh/about_screen.dart`),
  and Play Console has it as the listing's policy URL.

So the source to move is the repo's markdown, not the live page.

### Steps

1. **Build the page from the markdown.** `build.mjs` reads
   `docs/play-store/privacy-policy.md`, splits it at `## Tiếng Việt` and
   `## English`, and writes `/privacy/` and `/en/privacy/` in the landing
   page's style. The markdown stays the one place the policy is edited.
2. **Fill the two blanks in the markdown:** contact `help@long-ky.com`, and
   the last-updated date set to the day it goes live.
3. **Point the landing footer** at `/privacy/` and add both pages to the sitemap.
4. **Deploy** (`npm run build && npx wrangler deploy`).
5. **Keep the old address working.** Installed copies of the app (1.2.0 and
   older) open `binh-nt.dev/long-ky/privacy`. Add one Cloudflare redirect rule
   on `binh-nt.dev`: `/long-ky/privacy` → `https://long-ky.com/privacy` (301).
   No change to the portfolio code.
6. **Change the app** to `https://long-ky.com/privacy`: the constant, the two
   "couldn't open the browser" strings, and `about_privacy_test.dart`. It
   ships with the next app release.
7. **You change the policy URL in Play Console.**

### What it waits on

`long-ky.com` still shows the Squarespace page. Steps 1 to 4 can be done now
and are visible on the `workers.dev` address. Steps 5 to 7 must wait until
`long-ky.com` points at the landing site, or the policy link would break.

---

## 2. The two videos

### What I found

You are right. I measured both clips frame by frame with the system video
decoder, next to a clip from the app that is known to move:

| Clip | Pixels that change from the first frame |
| --- | --- |
| `dragon.mp4` | 0.0% |
| `nha-tran.mp4` | 0.0% |
| `content/eras/dien-bien-phu/cover.mp4` (control) | 27% to 64% |

They are still images saved as video.

**Why:** to get a loop with no visible jump, I gave the model the same
picture as both the first and the last frame. It filled the gap between two
identical pictures with nothing. I then put them on the page without watching
them. I had said I could not confirm autoplay in the preview; I never checked
that anything moved at all.

**What it cost you:** about 30 Higgsfield credits (three clips; the third,
Hồng Bàng, was never used) and 4 MB of dead weight on the live page.

### Steps

1. **Remove both files now** and the code that loads them. The page looks the
   same and is 4 MB lighter. No credits.
2. **Retry one clip only, as a test** (the dragon, 10 credits): start frame
   only, with the motion spelled out.
3. **Gate it.** A clip goes on the page only if the same frame measurement
   shows real movement (at least 10% of pixels changing mid-clip) and you
   have watched it. Otherwise it is discarded.
4. **Make it loop** by cross-fading two copies of the clip in the page (about
   20 lines of JS), since a clip with no fixed last frame does not loop by
   itself. No extra tools needed.
5. Only if the dragon works: do Bạch Đằng the same way.

---

## 3. Portrait audit: avatar against full body

### Scope and method

- **Eras checked:** Hồng Bàng to Tự Đức, 26 eras, **110 pairs**. Cần Vương
  onward is built from photographs, so it is outside this check.
- **Local files are what the app serves.** I compared 12 local files with the
  ones on `media.binh-nt.dev`; they are the same pictures.
- **How:** one row per person showing the avatar, the head of the full body
  enlarged, the full body, and the feet enlarged. A pair fails when it reads
  as a different depiction: different headgear, outfit, beard, age or face.
- **These are my judgements from reduced-size sheets.** Overrule any line.

### Result

| | Pairs |
| --- | --- |
| Clear mismatch, regenerate | **59** |
| Borderline (a cape, a plume, a slightly different crown) | 18 |
| Match | 33 |

**One thing to know:** the 1.2.0 release notes say full bodies from Hồng Bàng
to the Northern rule now match their avatars. This audit finds 17 clear
mismatches in those eras. I do not know whether that fix covered fewer people
or did not land.

### Clear mismatches (avatar → full body)

| Era | Person | What differs |
| --- | --- | --- |
| Hồng Bàng | `au-co` | patterned robe with collar → strapless wrap, bare shoulders |
| | `thuy-tinh` | dark blue robe → bare chest, necklace, wild hair |
| Nhà Triệu | `cu-thi` | simple hairpins → phoenix crown with pendants |
| | `lu-gia` | topknot, grey hair showing → brown cap |
| Hai Bà Trưng | `ma-vien` | plumed helmet → horned helmet |
| | `trung-nhi` | bare head, topknot → feathered helmet |
| Bà Triệu | `ba-trieu` | different face |
| | `luc-dan` | cap and plain robe → topknot, armour, cape |
| Vạn Xuân | `ly-nam-de` | purple cap, short beard → gold crown, long beard |
| | `pham-tu` | helmet → bare head, long grey beard |
| | `tinh-thieu` | black hat and robe, goatee → purple, clean-shaven |
| | `trieu-quang-phuc` | older, heavy face → young face, cape |
| Mai Hắc Đế | `duong-tu-huc` | winged gold helmet → black hat, cape |
| | `quang-so-khach` | winged official hat, brown robe → armour |
| Phùng Hưng | `phung-hung` | headwrap, brown tunic → topknot, grey tunic |
| Khúc Thừa Dụ | `khuc-thua-du` | old man, grey goatee → middle-aged, clean-shaven |
| | `khuc-thua-my` | avatar is a blue single-colour plaque; hat and face differ |
| Ngô Quyền | `kieu-cong-tien` | headband, no helmet → helmet, green armour |
| | `ngo-quyen` | bare head, no beard → conical helmet, grey beard, cape |
| Đinh | `dinh-tien-hoang` | small crown, goatee → large crown, clean-shaven |
| | `le-hoan` | no plume, beard → plume, clean-shaven; avatar face is red like a statue |
| Tiền Lê | `duong-van-nga` | older, green robe → younger, gold robe |
| | `hau-nhan-bao` | gold-rimmed helmet, full beard → winged dark helmet, thin goatee |
| Lý Thái Tổ | `dao-cam-moc` | plain black hat and robe → ornate turban and robe, older |
| Lý Thái Tông | `ly-thai-tong` | gold cap → dark jewelled crown |
| | `ly-thanh-tong` | topknot crown → gold cap |
| | `y-lan` | young woman → older woman |
| Lý Nhân Tông | `ly-thuong-kiet` | helmet, no beard → bare head, goatee, red cape |
| Trần Thái Tông | `tran-thu-do` | dark hair, robe → grey beard, armour |
| Trần Hưng Đạo | `tran-hung-dao` | black beard, no cape → greying, red cape; barefoot |
| Lê Lợi | `le-loi` | gold headband, full beard → gold cap, goatee |
| | `nguyen-chich` | headband, armour → hood and cloak |
| | `nguyen-trai` | round cap, green robe → winged hat, black robe |
| Lê Thánh Tông | `than-nhan-trung` | small cap, blue robe → winged hat, brown robe |
| Nam–Bắc triều | `mac-dang-dung` | winged hat, heavy full beard → small cap, thin goatee |
| | `nguyen-hoang` | old, navy robe → younger, gold-red robe |
| | `nguyen-kim` | topknot crown, blue robe → tall hat, red robe |
| | `trinh-kiem` | headband → gold cap, long hair |
| | `trinh-tung` | gold armour, slim → fur collar, moustache |
| Trịnh–Nguyễn | `dao-duy-tu` | old → younger, long hair |
| | `nguyen-phuc-nguyen` | navy robe → gold-brown robe, different cap |
| | `nguyen-phuc-tan` | conical hat, full beard → turban, clean-shaven |
| | `trinh-trang` | gold crown, gold-black robe → red turban, navy robe |
| Tây Sơn | `ngo-thi-nham` | folded hat, gaunt → round cap, fuller face |
| | `nguyen-nhac` | pointed gold crown, armour → winged gold hat, robe |
| | `nguyen-thiep` | black turban and robe → brown cap, blue-grey robe |
| | `quang-trung` | brown cap, beard → tall black helmet, no beard |
| | `ton-si-nghi` | plain cap → fur hat with peacock feather, younger |
| Gia Long | `ba-da-loc` | different face |
| | `gia-long` | no beard, small crown → long goatee, large crown |
| | `le-van-duyet` | turban → winged hat |
| | `nguyen-van-thanh` | gold-brown turban and robe → black turban, navy robe |
| Minh Mạng | `le-van-khoi` | full beard → clean-shaven |
| | `minh-mang` | red-gold crown → different cap |
| | `nguyen-cong-tru` | turban, navy robe → square hat, green robe |
| | `truong-minh-giang` | red robe with armour → blue-purple robe |
| Thiệu Trị | `nguyen-tri-phuong` | conical hat → cap with phoenix badge |
| | `truong-dang-que` | turban → winged hat |
| Tự Đức | `truong-dinh` | navy robe, stubble → brown-red robe, full beard |

Âu Lạc has no clear mismatch.

### Borderline (18)

`vua-hung`, `cao-lo`, `trieu-ai-vuong`, `trung-trac`, `tran-ba-tien`,
`duong-dinh-nghe`, `luu-hoang-thao`, `pham-cu-lang`, `le-phung-hieu`,
`tran-khanh-du`, `tran-quang-khai`, `tran-quoc-toan`, `le-lai`, `lieu-thang`,
`ngo-si-lien`, `nguyen-xi`, `trinh-tac`, `thieu-tri`.

Same person, same dress in broad terms; the full body adds or changes one
thing (a cape, a plume, a goatee, the size of a crown).

### Other defects the audit turned up

- **Barefoot in armour or court dress:** `tran-hung-dao`, `tran-khanh-du`,
  `tran-nhan-tong`.
- **Barefoot, probably on purpose:** the nine Hồng Bàng figures, plus `cao-lo`
  and `my-chau` in Âu Lạc. Also `van-hanh` (a monk) and `nguyen-trung-truc`
  (a fisherman on his boat), which are right as they are.
- **Avatars that are themselves wrong:** `mai-hac-de` (white bars down both
  sides), `phung-hai` (drawn as a bust on a wooden stand), `khuc-thua-my`
  (single-colour plaque), `le-hoan` (red statue-like face).
- **`o-ma-nhi` full body:** a black band across the bottom of the picture.
- Not in scope, noted in passing: three Cần Vương "full" images are head and
  shoulders only (`nguyen-thien-thuat`, `phan-dinh-phung`, `ton-that-thuyet`).

### How to fix

- **The avatar is the reference; the full body is regenerated to match it.**
  This is the direction the earlier fix took, and the avatar is what readers
  meet first (lists, street map, quiz).
- **Four exceptions**, where the avatar is the faulty one: for `mai-hac-de`,
  `phung-hai`, `khuc-thua-my` and `le-hoan` the avatar is regenerated from the
  full body instead.
- **Inputs per image:** the avatar (face, age, beard, headgear, dress) and the
  current full body (pose, background, palette), so the era's look is kept.
- **House rules as before:** `nano_banana_pro`, 2:3 at 1696×2528, the sơn mài
  style lock, full-bleed, no text or Hán tự, no map, brief re-checked against
  the person's bio.
- **New rule: footwear fits rank and era.** Boots with armour, court shoes
  with robes. Barefoot only where the role calls for it.

### Checks and safety

- **Every new image is checked before it replaces anything.** I rebuild the
  same sheet (avatar beside the new full body) and compare each one. A failed
  image is re-rolled at most twice, then listed for you instead of shipped.
- **Originals are backed up first** to `.archive/portraits-2026-10-13/`
  (git-ignored). Content images are not in git, and pushing to the sources
  bucket overwrites.
- **Pilot before the bulk:** Tây Sơn (5), Trần Hưng Đạo and Thánh Gióng. You
  look at those seven; the other eras follow only if you are happy.
- **Publishing is yours to trigger:** `push_sources`, then `publish_content`
  with a dry run first. Readers get the new portraits over the air, with no
  app release.
- **Afterwards:** re-check the Play Store screenshots and the landing page's
  copies of them, since some show portraits that will have changed.

---

## 4. Thánh Gióng full body

- **Now:** standing still, holding a sword, barefoot, no horse. The sword is
  not in the legend.
- **New brief:** the same young warrior as the avatar (dragon helmet, bronze
  scale armour, same face), astride a rearing iron horse with fire coming
  from its mouth, one arm raised holding an uprooted clump of bamboo, roots
  and leaves showing. Same jade Đông Sơn drum background. Boots or greaves
  to the foot.
- **It echoes art you already have:** `content/eras/hong-bang/events/thanh-giong.png`
  shows him mounted with a bamboo stalk.
- **Framing:** a horse in a 2:3 portrait needs care so the face stays large
  enough. I generate two or three and you pick.
- **The bio stays as it is.** It mentions the iron horse, iron whip and iron
  armour, not the bamboo, which comes from the folk telling. A sentence can
  be added if you want one, but it would need a source like the rest.

## 5. Trần Hưng Đạo full body

- **Now:** barefoot, and also unlike his avatar (red cape, older greying face).
- **New brief:** matches the avatar (black beard, helmet with the topknot
  plume, dark lamellar with the gold dragon), no cape, war boots, same red
  lacquer and gold dragon background, hands on the sword as now.
- `tran-khanh-du` and `tran-nhan-tong` get footwear in the same batch.

---

## Cost

`nano_banana_pro` at 2K costs **2 credits an image** (checked today). Balance: 923.

| Work | Images | Credits, with re-rolls |
| --- | --- | --- |
| 59 clear mismatches | 59 | about 165 |
| Footwear only, avatar-only defects, `o-ma-nhi`, Thánh Gióng variants | 8 | about 25 |
| Borderline 18, if you want them | 18 | about 50 |
| One test video | 1 | 10 |

About **200 credits** without the borderline set, about 250 with it.

## Order of work

1. **No credits:** remove the two still videos; build and deploy the privacy pages.
2. **Pilot (about 20 credits):** Tây Sơn, Trần Hưng Đạo, Thánh Gióng. You review.
3. **The rest of the portraits,** era by era, each batch checked on a sheet.
4. **You publish** the content pack.
5. **One test video,** if you still want motion on the landing page.
6. **When `long-ky.com` is live:** the redirect rule, Play Console, the app constant.

## Decisions needed

1. **Which picture is the reference?** The avatar, with the full body redrawn
   to match (recommended, with the four exceptions above)? Or the other way?
2. **The 18 borderline pairs:** leave them (recommended), or redo them too?
3. **Barefoot in Hồng Bàng and Âu Lạc:** keep as it is (recommended), or give
   them footwear as well?
4. **Videos:** remove and retry the dragon once as a 10-credit test
   (recommended), or remove and stop there?
