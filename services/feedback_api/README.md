# feedback_api

A tiny public Cloudflare Worker. The app's "Báo sai sót" sheet posts a
report here and the Worker emails it **from `admin@long-ky.com` to
`help@long-ky.com`**, so a reader never has to type an address or open a mail
app. Nothing about the reader is collected: no Reply-To, no account, no email.

`POST /feedback` with `{"subject": "[Long Ký] …", "body": "…"}`

| Status | Meaning |
|---|---|
| 200 | Sent. |
| 400 | Not a valid report (not JSON, subject without the `[Long Ký] ` prefix or with a line break, empty or over-long body). |
| 429 | Over the per-IP rate limit (5 a minute). |
| 502 | The mail relay refused — the app lets the reader retry. |

## One-time Cloudflare setup

1. `long-ky.com` is a Cloudflare zone with **Email Routing** enabled.
2. Add `help@long-ky.com` under *Email Routing → Destination addresses* and
   verify it (the binding in `wrangler.toml` can only send to a verified
   destination).
3. `cd services/feedback_api && npm install && npx wrangler login`
4. `npm run deploy` — this also creates the `feedback.long-ky.com` route.

No secrets: the `send_email` binding is the credential, and it is locked to
`help@long-ky.com`.

## Local dev

```bash
npm install
npm run typecheck
npm test
```

Tests inject a fake sender; nothing touches the network.
