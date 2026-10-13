# Long Ký landing page

Static page, no framework: HTML template + SCSS + about 100 lines of JS,
built by one Node script. Vietnamese at `/`, English at `/en/`.

```bash
cd apps/landing
npm install
npm run build          # → dist/
npm run dev            # build, watch, serve on http://localhost:3030
```

## Where things are

| Path | What |
| --- | --- |
| `src/layers.json` | The seven "layers" of the descent: copy (vi/en), art, screenshot |
| `src/i18n/{vi,en}.json` | Page strings |
| `src/index.template.html` | The page; `build.mjs` renders it once per language |
| `src/styles/` | SCSS. Tokens mirror `packages/ui_kit` |
| `src/assets/` | Optimised images, fonts, video loops (committed) |
| `public/` | Copied as is: favicon, share image, `_headers`, `_redirects` |
| `tool/make-images.mjs` | Rebuilds `src/assets/img` + fonts from `brand/` and `content/` |
| `tool/make-og.mjs` | Rebuilds `public/og.jpg` |

Counts on the page (streets, figures, events, eras) and the depth rail are
read from `content/*.json` at build time, so they cannot drift from the app.

## The download link

The QR code and every button point to **`https://long-ky.com/get`**.

- **Now** (Play listing private): `/get` serves a "coming soon" page.
- **When the listing is public:** put this in `public/_redirects` and deploy:
  ```
  /get    https://play.google.com/store/apps/details?id=app.longky  302
  /en/get https://play.google.com/store/apps/details?id=app.longky  302
  ```
  The QR on every screen and print keeps working. Nothing to reprint.

## Deploy (Cloudflare Workers static assets)

Wrangler 4.x folded Cloudflare Pages into Workers, so the site is a Worker
that serves `dist/` (config in `wrangler.jsonc`).

```bash
npx wrangler login      # once
npm run build
npx wrangler deploy
```

Live address: https://long-ky-landing.binhnt-010896.workers.dev

To serve it at `long-ky.com`: the domain's DNS must be on Cloudflare, then
Workers & Pages → `long-ky-landing` → Settings → Domains & Routes → Add →
Custom domain (`long-ky.com`, `www.long-ky.com`). Copy the existing mail
records into Cloudflare DNS before changing nameservers.

## Scroll-scrubbed video

The hero dragon and the 1954 / 1789 / 1288 covers are **scroll-scrubbed**:
scrolling moves the playhead, stopping holds the frame, nothing autoplays.
Layers map their whole pass through the screen to `data-from..data-to` seconds
(`videoRange` in `src/layers.json`); the hero is pinned for one extra screen.

Clips are upscaled to 1080p with Higgsfield (Topaz Video, ~3 credits per 5 s
clip). Clips must be **all-keyframe** encodes so any time seeks instantly.
Originals live in `brand/landing/video-originals/`, upscaled masters in
`brand/landing/video-upscaled/`; encode with the system encoder:

```bash
swiftc -O -o /tmp/scrub tool/scrub.swift
/tmp/scrub brand/landing/video-upscaled/<name>.mp4 src/assets/video/<name>.mp4 1440 1080 8000000 2   # w h bitrate keep-every-Nth (dragon: 810 1440 4500000)
swiftc -O -o /tmp/frame tool/frame.swift && /tmp/frame <original.mp4> out.png 0.5   # grab a poster frame
```

The still under each video (`poster-*` in `src/assets/img`) is its first used
frame. Visitors with reduced motion or data saver get the still only.

## Motion loops (older)

`src/assets/video/*.mp4` are image-to-video loops generated from art that is
already in the app (dragon splash, period covers). The page works without
them: a still image sits under every video.
