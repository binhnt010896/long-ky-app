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

## Motion loops

`src/assets/video/*.mp4` are image-to-video loops generated from art that is
already in the app (dragon splash, period covers). The page works without
them: a still image sits under every video.
