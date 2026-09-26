# Long Ký — Play Console forms (drafts)

For **Monetize → App content** in Play Console, before any release beyond
internal testing. Answer these forms as shown; adjust only if something in
the app has changed since this was drafted.

## Data safety questionnaire

- **Does your app collect or share any of the required user data types?**
  **Yes** — Firebase Analytics and Crashlytics collect app activity and
  diagnostic data (see below); no personal data (name, email, etc.) is
  collected. Google Play Billing handles purchase data itself, outside the
  app.
- **Data collected:**
  - **App activity → App interactions** (screens viewed, in-app actions
    such as Câu đố/Chào cờ/atlas/tip usage) — Purpose: **Analytics**.
    Optional (the in-app switch, default on).
  - **App info and performance → Crash logs, Diagnostics** — Purpose:
    **Analytics, App functionality**. Optional (same switch).
  - **Device or other IDs** (Firebase's own installation identifier, not
    the advertising ID — this app never collects or uses the advertising
    ID) — Purpose: **Analytics**. Optional (same switch).
- **Data shared with third parties:** none directly by the app beyond
  Google, which processes Analytics/Crashlytics data as Long Ký's service
  provider (not a separate third-party share for Play's purposes). Google
  Play Billing and the Cloudflare CDN are platform/infrastructure services;
  if the form asks about them explicitly, note "processed by Google Play
  Billing for purchases; standard CDN server logs for content delivery, not
  linked to identity."
- **Is all user data encrypted in transit?** **Yes.**
- **Does your app allow users to request data deletion?** The in-app switch
  stops collection going forward; Firebase's own instance identifiers are
  not linked to a real-world identity, so there is nothing to tie a
  deletion request to. State this plainly if the form asks.
- **Advertising ID:** **not collected** — confirm the merged release
  manifest has no `AD_ID` permission before answering this (see
  EXECUTION.md's Cycle F verification steps).

## Content rating questionnaire (IARC)

Answer honestly per category; expected outcome for this app:

- Violence: historical war content is depicted in **text and illustration**,
  not graphic imagery — describe as mild/historical educational violence,
  no gore.
- Sexual content: none.
- Profanity: none.
- Drugs/alcohol/gambling: none.
- User-generated content / user interaction: none (no chat, no accounts).
- **Expected rating: "Everyone" / PEGI 3** or the equivalent low tier in
  most regions, given educational historical content.

## Target audience and content

- **Target age group:** general audience; if Play asks for a primary range,
  **13+** is a reasonable choice (avoids the stricter "designed for
  children" review track; the app is not designed for or targeted at
  children specifically).
- **Ads:** declare **no ads**.
- **In-app purchases:** declare **yes** — one consumable product family
  (`long_ky_tea`, `long_ky_tea_2`, `long_ky_tea_3`), $0.99–$2.99.

## Store listing drafts

**Short description (VI, ≤80 chars):**
> Nghìn năm sử Việt — đọc, xem, học lịch sử Việt Nam qua từng kỷ nguyên.

**Short description (EN, ≤80 chars):**
> A thousand years of Vietnamese history — read, explore, learn.

**Full description (VI):**
> Long Ký là một cuốn sử Việt sống động trên điện thoại — từ thời Hồng Bàng
> dựng nước đến ngày nay. Mỗi kỷ nguyên là một chương: nhân vật, sự kiện, và
> nguồn sử liệu gốc luôn hiện rõ, không mơ hồ.
>
> • Hơn 35 kỷ nguyên, hàng trăm sự kiện, đầy đủ trích dẫn nguồn
> • Bản đồ lãnh thổ qua các thời kỳ
> • Câu đố — thử sức hiểu biết của bạn về sử Việt
> • Chào cờ — nghi thức chào cờ hằng ngày
> • Miễn phí, không quảng cáo. Nếu thích, mời Long Ký một chén trà.

**Full description (EN):**
> Long Ký is Vietnamese history, alive on your phone — from the founding of
> Hồng Bàng to the present day. Every era is a chapter: figures, events, and
> the original chronicle sources are always visible, never vague.
>
> • 35+ eras, hundreds of events, every one cited
> • A territory atlas across the centuries
> • A quiz to test what you've learned
> • A daily flag-salute ritual
> • Free, no ads. If you like it, buy Long Ký a cup of tea.

**Assets still needed from you** (Claude can't generate these without a
device or your art assets):
- App icon 512×512 (from the existing seal asset — Claude can resize it)
- Feature graphic 1024×500
- 2–8 phone screenshots (Claude can capture these from the web build at
  phone width once you're ready, though a real-device capture will look
  better with live art)
