# Plan: Long Ký landing page (`apps/landing`)

Planned 2026-10-12. **Not started.** Nothing here is built yet.

## What was asked

> A landing page that introduces Long Ký. Immersive: each scroll takes the
> visitor deeper into the history of Vietnam. Include a download QR and link.
> Support email `help@long-ky.com`. Use Higgsfield for video/images if needed.
> Pure HTML and CSS (SCSS), no web framework. Code in `apps/landing`.

## What I found in the repo (and what it changes)

| Finding | Consequence |
| --- | --- |
| The Play listing `play.google.com/store/apps/details?id=app.longky` returns **404** today (closed test, not public). iOS is not started. | The QR and button must not point straight at the store. See "Download". |
| `long-ky.com` is live but shows a **Squarespace "Coming Soon"** page. | Going live needs a DNS change at Squarespace, without touching the mail records for `help@long-ky.com`. |
| Almost all the art exists: 17 period covers, 38 era covers, layered scene art per era (`sky`, `ridge-far`, `ridge-near`, `glow`), the gold dragon splash, 4 logos, 2 cover videos, 5 store screenshots per language. | Higgsfield is needed only for motion, not for new pictures. |
| Content images are git-ignored (`content/**/*.png`), 2–3.7 MB each. | The landing page keeps its own small, optimised copies inside `apps/landing`, so it builds on any machine. |
| Brand tokens are in `packages/ui_kit`: lacquer `#07100f`, gold `#C9A24B` / `#E6C877`, parchment `#f2ead9`, Playfair Display + Be Vietnam Pro, and one accent colour per period in `content/periods.json`. | The page reuses these exactly, so it looks like the app. |
| No `sass`, `ffmpeg`, `cwebp` or `wrangler` installed. Node 24 and the Firebase CLI are. | Tools come in as npm dev dependencies of `apps/landing` only. |

## Stack: you are right, with two small corrections

No React, no Next. One page, no state, no routing: a framework would add
weight and nothing else.

1. **SCSS needs a build step anyway**, so there is a small Node script
   (`build.mjs`, about 150 lines, no bundler). It also does three jobs that
   would be tedious by hand: renders one HTML template into Vietnamese and
   English, converts images to AVIF/WebP, and draws the QR code as an SVG.
2. **A little plain JavaScript is needed** (about 100 lines, no library):
   - start and stop videos as they enter and leave the screen;
   - a fallback for browsers without CSS scroll-driven animations (older
     Safari, and Firefox the last time I checked; I will confirm at build time).

The motion itself is CSS: `position: sticky` scenes driven by
`animation-timeline: view()`, which runs off the main thread and stays smooth
on phones. With JavaScript off, or with "reduce motion" on, the page is a
normal illustrated long read and loses nothing important.

## The concept: a descent

**Scrolling down is going back in time.** The visitor starts on the surface,
today, and each scroll takes them one layer deeper, until they reach the dawn
of the nation at the bottom. There the page says: now start from the
beginning, and offers the app, which opens at Hồng Bàng.

Why this direction: "deeper" then means what it says, and it gives the page a
hook that is about the visitor, not about us. The first layer is the street
they live on. *Dưới mỗi tên đường là một nghìn năm* (under every street name
lies a thousand years).

Three things carry the descent:

- **The dragon.** The gold dragon from the splash art is the hero. *Long Ký*
  is the dragon's record, so the dragon leads the way down.
- **The depth rail.** A thin gold line on the edge of the screen, with one
  tick per period in that period's accent colour and a year that counts
  backwards from 2026 to 2879 TCN. It is built from `content/periods.json`,
  so it never drifts from the app.
- **Colour.** The page background shifts to each period's accent as its layer
  passes, then returns to lacquer.

### The layers

Seven layers, not all 17 periods: a landing page that long loses people. The
other periods pass as ticks on the rail.

| # | Year | Layer | Art (already in the repo) | App feature it shows |
| --- | --- | --- | --- | --- |
| 0 | 2026 | **Hero.** Dragon, wordmark, one line, download button | `brand/splash/splash-dragon.png` | |
| 1 | Today | **The street you live on** | street map screenshot in a phone frame | Street map, 285 streets |
| 2 | 1975 – 1945 | **Kháng chiến** | `eras/dien-bien-phu/cover.mp4`, period covers | Event pages with cited sources |
| 3 | 1789 | **Tây Sơn** | `periods/tay-son.png` | Figures, 309 people |
| 4 | 1288 | **Nhà Trần, Bạch Đằng** | `periods/nha-tran.png` | Territory atlas |
| 5 | 1010 | **Nhà Lý, Thăng Long** | `periods/nha-ly.png` | |
| 6 | 938 – 111 TCN | **A thousand years** | `periods/bac-thuoc.png` | |
| 7 | 2879 TCN | **Hồng Bàng, the dawn** | the four scene layers, as true parallax | |
| 8 | | **Start from the beginning.** QR, store button, support | logo seal | Quiz, Chào cờ, free and no ads |

Each layer is one pinned full-screen scene: the art, the period's kicker and
title, one or two sentences, and (for four of them) a phone showing the
matching screen of the app.

**Words.** Vietnamese is the main language at `/`, English at `/en/`. Period
titles, kickers and subtitles come from `content/periods.json` as they are.
The page makes **no historical claim that the app's content does not already
make**. I draft the remaining copy; you review it before launch.

**Counts** (285 streets, 309 people, 247 events, 38 eras) are read from the
content files at build time, not typed in.

## Download

- **One link everywhere:** the QR and every button go to
  `https://long-ky.com/get`. That address redirects to the store. The QR then
  survives any change: the listing going public, an iOS release, a new store
  URL. Nobody has to reprint or reshare it.
- **Desktop:** the QR is large, with the store badge beside it. The visitor is
  on a computer and the app is on their phone.
- **Phone:** the store button is primary and the QR is small. A slim "Tải ứng
  dụng" bar stays at the bottom of the screen after the hero, so nobody has to
  reach the last layer to install.
- **Until the listing is public,** `/get` cannot reach the store. This needs
  your decision (see the end).
- **iOS:** no badge until there is an app. One line: "iOS: sắp có".

## Support and footer

- `help@long-ky.com` as a `mailto:` link, in the last layer and the footer.
- Privacy policy: link to the current `https://binh-nt.dev/long-ky/privacy`.
  Later the page can host it at `long-ky.com/privacy` from
  `docs/play-store/privacy-policy.md`.
- A short note that illustrations are made with AI assistance, matching the
  notice page in the app.

## Higgsfield: motion only

All generation starts from art that is already in the app, so nothing new is
invented about history and the style stays the same.

| Asset | Source | Use |
| --- | --- | --- |
| Hero loop, 6–8 s, seamless | `splash-dragon.png` | Clouds drift, the dragon breathes |
| Bạch Đằng loop | `periods/nha-tran.png` | Fire and water move |
| Hồng Bàng loop | `periods/hong-bang.png` | Mist, cranes |
| One or two more, if the first three work well | period covers | |

Not generated: the share image (composed from the logo and dragon), the QR,
textures and dividers (CSS and SVG).

Before generating I check the Higgsfield balance and tell you the cost. Every
loop has a still image as fallback, so the page does not depend on any of them.

## Folder

```
apps/landing/
  package.json          sass, sharp, qrcode (dev only); scripts: dev, build
  build.mjs             template → 2 languages, SCSS, images, QR
  README.md             how to run, build, deploy
  src/
    index.template.html
    i18n/vi.json  en.json
    layers.json         which periods are layers, their copy and art
    styles/             main.scss + _tokens _type _hero _layer _rail _download _motion
    scripts/main.js
    assets/             fonts (woff2), optimised images, video loops
  public/               favicon, share image, robots.txt, redirects
  dist/                 build output, git-ignored
```

It has no `pubspec.yaml`, so Melos and the Dart workspace ignore it. I add a
`landing` entry to `.claude/launch.json` so it can be previewed like the two
Flutter apps.

## Quality bar

- **Speed:** first screen under 600 KB, largest paint under 2.5 s on 4G.
  Images as AVIF with WebP fallback and `srcset`. Videos under 1.5 MB each,
  loaded only near the screen, never on "data saver" or "reduce motion".
- **Phones first.** Checked at 375 px, tablet and desktop.
- **No scroll hijacking.** The visitor's scroll speed is never overridden.
- **Access:** real headings and text (not text in images), contrast checked
  on every accent colour, keyboard reachable, alt text.
- **Sharing and search:** title, description, share image, `hreflang` for
  both languages, app structured data, sitemap.
- **Fonts:** Playfair Display and Be Vietnam Pro, self-hosted, Vietnamese
  subset. No request to Google.
- **Tracking:** none in the first version.

## Steps

1. **Skeleton.** Folder, build script, tokens, the whole page as plain static
   HTML in both languages with the download block and QR. Reviewable already.
2. **Art.** Optimise existing images. Capture fresh app screenshots from the
   Flutter web build. Generate the Higgsfield loops.
3. **Motion.** Pinned scenes, parallax, depth rail, year counter, colour
   shifts, fallbacks.
4. **Check.** Phone, tablet, desktop; reduced motion; no JavaScript; Chrome,
   Safari, Firefox; speed audit. Screenshots as proof.
5. **Deploy.** Hosting, the `/get` redirect, DNS. Needs you.

Steps 1 to 4 need nothing from you except the two decisions below.

## Hosting (decide by step 5)

**Recommended: Cloudflare Pages.** You already use Cloudflare for media and
the CMS Worker, bandwidth is not metered, and redirects are a one-line file.
Firebase Hosting would also work (the project and CLI are there), but its free
tier allows 360 MB of transfer a day, which a page with video can use up.

Either way, `long-ky.com` has to be pointed away from Squarespace, keeping the
mail records. That is a change in your Squarespace account, so it is yours to
make; I will write out the exact records.

## Decisions needed

1. **Direction.** Descend backwards in time, from today's street to Hồng Bàng
   (recommended)? Or forwards, from Hồng Bàng to today?
2. **Before the Play listing is public,** what should the download button do?
   - **a.** Build now, publish the page when the listing is live
     (recommended: nothing half-working goes out).
   - **b.** Publish now with "Sắp có trên Google Play", and `/get` shows a
     short coming-soon page.
   - **c.** Publish now and send `/get` to the closed-test sign-up, to help
     reach the 12 testers Play requires.
