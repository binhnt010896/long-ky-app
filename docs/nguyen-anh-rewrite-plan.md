# Nguyễn Ánh rewrite: plan (item 5)

Status: **planned, not started** · 2026-10-06

## Why

The Gia Long era and the people and events around it read as a hero story
("Người thống nhất giang sơn", "điều chưa từng có", "bền chí", and "việc mà
đời sau còn tranh luận" for the cầu viện). The text was written at project
init (commit `1b7ed9e`, 2026-09-18) with *Đại Nam thực lục*, the Nguyễn court's
own chronicle, as its only source. No line-level citations were recorded.

## Locked decisions

1. **Framing follows the Vietnam-Gov view.** Nguyễn Ánh brought in Siam (1784)
   and signed the Versailles treaty with France (1787): "cõng rắn cắn gà nhà,
   rước voi giày mả tổ". The credit for unifying the country and defending its
   sovereignty goes to Nguyễn Huệ and the Tây Sơn movement.
2. **Sources.** Any site under **gov.vn** is trusted, with
   **Viện Sử học** (<https://viensuhoc.vass.gov.vn/>) and its
   *Lịch sử Việt Nam* first. Nguyễn court works (*Đại Nam thực lục*,
   *Đại Nam chính biên liệt truyện*) are used only for dates and clearly
   attributed facts, never for framing.
3. **Tone.** Sober and on the record, as a history app should be
   (no "bọn lật sử", no "tội ấy lớn lắm"). SGK and Viện Sử học phrases are
   quoted with attribution.
4. **Accuracy guards** (keep these in, or keep them out):
   - Keep: the Versailles treaty was **never carried out**. Say it as a fact
     after the condemnation, not as an excuse.
   - Don't copy: Phan Bá Vành (1821–27) is under **Minh Mạng**, not Gia Long.
   - Don't copy: "bế quan tỏa cảng" belongs to Minh Mạng and later, not Gia Long.
   - Unverified, so leave out unless a gov.vn source confirms them:
     "Cao Bá Chúc", and "Nguyễn Văn Nhàn, Lê Văn Bột".
5. **Facts that stay, written neutrally:** he took the throne in 1802; the
   country was named Việt Nam in 1804; the capital was at Huế; the Gia Long
   Code (1815); he died in 1820. These are stated as record, without praise
   ("lập nên", not "khai sáng"; "cai quản", not "thu giang sơn về một mối").

## Scope (exact fields)

| File | Item | Fields |
|---|---|---|
| `content/people.json` | `gia-long` | `epithet`, `bio` (vi + en) |
| | `ba-da-loc` | `epithet` ("Người phò tá Nguyễn Ánh"), `bio` ("hết lòng giúp đỡ", "Không nản") |
| | `le-van-duyet`, `nguyen-van-thanh` | the "diệt Tây Sơn / cuộc thống nhất" sentences only |
| | every other person mentioning Nguyễn Ánh / Gia Long (46 mentions in the file) | tone sweep only (e.g. `trinh-hoai-duc` reads neutral already) |
| `content/eras/gia-long.json` | era | `title`, `kicker` ("Thống nhất sơn hà"), `subtitle`, `overview`, `primarySource` |
| `content/events.json` | `gian-nan-phuc-quoc`, `cau-vien-ba-da-loc`, `gia-dinh-lon-manh`, `bac-tien-thong-nhat`, `len-ngoi-viet-nam`, `kinh-do-hue-luat-gia-long` | `title`, `summary`, `body`, `details`, `pullQuote`, `citation` (all six cite ĐNTL Quyển 1–6 today) |
| | `mo-coi-dai-nam` | `pullQuote` ("thống nhất một dải") |
| | `dung-nghia-tay-son`, `rach-gam-xoai-mut`, `canh-tan-bang-ha` | `citation`: these cite *Ngụy Tây liệt truyện*, the Nguyễn court's hostile record of the Tây Sơn. Re-cite to Viện Sử học, and make the Nguyễn Ánh lines match the new framing |
| `content/eras/tay-son.json`, `minh-mang.json` | mentions | check that the "mất về tay Nguyễn Ánh" and "nối nghiệp vua cha" lines fit |
| `apps/mobile/lib/screens/prototype/territory_atlas_data.dart:240` | 1805 snapshot | subtitle "Gia Long thống nhất / Gia Long unifies the country" |

Flows through automatically: the quiz is built from event and era **titles**
and summaries (`quiz_generator.dart`), and the timeline, street card and event
figures read the epithet. No separate edits are needed, but they get checked
in step 6.

Out of scope unless you ask: the art itself (step 5 only reviews it), other
Nguyễn emperors' bios, and the street mapping (the only gia-long-era street is
Lê Văn Duyệt).

## Steps

1. **Research (read-only).** Pull the Viện Sử học and other gov.vn texts on:
   Nguyễn Ánh / Gia Long; cầu viện Xiêm 1784 and the Rạch Gầm – Xoài Mút
   battle; the Versailles treaty 1787; Tây Sơn's role in unification; the
   founding of the Nguyễn dynasty (1802), the name Việt Nam (1804), and the
   Gia Long Code. Save each source with its URL, title and a short excerpt in
   `docs/sources/nguyen-anh.md`, so every claim in step 2 points to a line.
   If gov.vn turns out to be thin on a point, stop and ask whether to widen
   the list (e.g. SGK published by NXB Giáo dục, *Tạp chí Cộng sản*,
   *Nhân Dân*, *QĐND*, which are not on gov.vn).
2. **Draft (no file edits).** Write the new vi + en text for every row in the
   scope table, with a source line under each claim, in
   `docs/drafts/nguyen-anh-rewrite.md`: before → after, field by field.
3. **Your review.** You approve or mark up the draft. Nothing changes in
   `content/` until you approve it.
4. **Apply.** Edit `content/` (events are raw JSON in the CMS anyway; people
   and era can go through the CMS form or the repo, your call). Run the
   content validator and formatter, edit the atlas subtitle, and run the
   mobile and core_domain tests.
5. **Art check.** Look at `gia-long` avatar/full and the era cover/scene for
   glorifying staging (a triumphant pose, a halo of light). Report only; any
   regeneration is a separate yes from you.
6. **Verify in the app** (Flutter web, cache-busted): the era hub, the
   character page, all six events, the quiz with the gia-long era, and the
   atlas at 1805.
7. **Ship.** Commit (`fix(content): …`). Publishing over the air (CMS
   `/publish` dry run, then the real publish) needs your yes first.

## Open questions

- Era title: "Gia Long dựng nhà Nguyễn" becomes something neutral such as
  "Nhà Nguyễn thành lập". Final wording comes in the step 2 draft.
- The epithet for `gia-long`: a plain role ("Vua đầu tiên của nhà Nguyễn")
  rather than an honorific. Final wording comes in the step 2 draft.
