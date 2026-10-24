# feedback_api

A tiny public Cloudflare Worker. The app's "Báo sai sót" sheet posts a
report here and the Worker emails it through Resend **from `admin@long-ky.com` to
`help@long-ky.com`**, so a reader never has to type an address or open a mail
app. Nothing about the reader is collected: no Reply-To, no account, no email.

`POST /feedback` with `{"subject": "[Long Ký] …", "body": "…"}`

| Status | Meaning |
|---|---|
| 200 | Sent. |
| 400 | Not a valid report (not JSON, subject without the `[Long Ký] ` prefix or with a line break, empty or over-long body). |
| 429 | Over the per-IP rate limit (5 a minute). |
| 502 | Resend refused — the app lets the reader retry. |

## One-time setup

long-ky.com's DNS stays at Squarespace (its help@ forwarding keeps working).

1. Resend: create an account, *Domains → Add domain* `long-ky.com`, and add
   the DNS records it lists in Squarespace (*Domains → long-ky.com → DNS*).
   Wait for the domain to show **Verified**.
2. Resend: *API Keys → Create*, permission "Sending access", domain
   `long-ky.com`. Copy the key (shown once).
3. `cd services/feedback_api && npm install && npx wrangler login`
4. `npx wrangler secret put RESEND_API_KEY` — paste the key.
5. `npm run deploy` — prints the `https://long-ky-feedback-api.<you>.workers.dev`
   URL; the app's `kFeedbackApiUrl` must point at its `/feedback`.

The only secret is the Resend key; it lives in Cloudflare, never in a file.

## Local dev

```bash
npm install
npm run typecheck
npm test
```

Tests inject a fake sender; nothing touches the network.
