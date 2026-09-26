# cms_api

The backend for the Long Ký admin CMS (`apps/admin`, not yet built — see
`EXECUTION.md`'s Cycle G). A small Cloudflare Worker, because the CMS itself
is a static Flutter web app and can never safely hold a GitHub token or R2
keys — anything shipped to a browser is readable.

It holds exactly two things the CMS can't:

- **R2 access** to the private `long-ky-sources` bucket, via a bucket
  **binding** (`SOURCES_BUCKET`) — no R2 access keys exist anywhere in this
  service's code or config.
- **A GitHub token**, scoped to `long-ky-app` only (contents + actions:
  write), stored as a Worker **secret** — never in a file, never in
  `wrangler.toml`.

## Auth

Every request needs `Authorization: Bearer <Firebase ID token>`. The Worker
verifies the token's signature against Google's own published JWKS, checks
it's for the `long-ky-app` Firebase project, and checks the token's email
against `ALLOWED_EMAILS` in `wrangler.toml`. The CMS's own URL is otherwise
public — this check is what actually gates access.

## Endpoints

| Method & path | Does |
|---|---|
| `GET /content` | Every `content/**/*.json` file at `main`'s head, plus the head commit's sha (the caller's `baseSha` for a later commit). |
| `POST /commit` | One atomic multi-file commit (`{baseSha, files, message}`) via the Git Data API. `files` maps path → new text, or `null` to delete. **409** if `main` has moved since `baseSha` at all (a simple, safe-by-construction policy — reload and retry). |
| `PUT /media?path=` | Streams an original into `long-ky-sources` at `path`. 415/413 for a disallowed type or a file over 100 MB. |
| `GET /media?path=` | Streams an original back — used for previewing art that hasn't been published (so isn't on the public `long-ky-content` CDN) yet. |
| `POST /publish {dryRun}` | Triggers `.github/workflows/publish-content.yml` on `main`. |
| `GET /publish/status` | The most recent publish run's status/conclusion/URL. |

## Local dev

```bash
npm install
npm run typecheck
npm test
```

`npm test` runs against a real (in-memory) R2 simulator for `SOURCES_BUCKET`
and a fake `fetch` for the GitHub API calls — no live network, no real
secrets needed to run the suite.

To actually run the Worker locally (`npm run dev`), create `.dev.vars`
(gitignored) with a real `GITHUB_TOKEN=…` line — `wrangler dev` picks it up
automatically. Don't put it in `wrangler.toml`.

## Deploying

```bash
npx wrangler login          # once
npx wrangler secret put GITHUB_TOKEN   # once, or whenever the token rotates
npm run deploy
```
