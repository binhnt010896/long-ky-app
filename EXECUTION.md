# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: Cycle Q is BUILT: the splash is the gold dragon-and-clouds art
(variant d1, Higgsfield `nano_banana_pro`) behind the seal and the wordmark in
Playfair Display Italic, with a slow 3 % drift, and Android's launch window is
lacquer-dark (no white blink). App bundle 1.1.0+8 built. Not yet seen on the
phone (it was locked); the other candidates are in `brand/splash/` (untracked).**

Earlier specs: M `cfa220a`, N `92e699f`, O `f56a4d7`, P `9552bb5` (each
`<sha>:EXECUTION.md`); what P shipped: `529f7a6:EXECUTION.md`.

## Audit of the previous plan

Done since the last plan (2026-10-01):
- **Cycle P finished on the phone (debug build):** landmarks, the zoom-13
  opening view, the centred search text. Three follow-ups found there and fixed:
  dimmer resting gold streets (`1fdfd71`); labels missing on phones that had
  opened the map earlier — the old on-disk tile cache, now a versioned folder
  (`1fdfd71`); too many labels — "Khu phố / Ấp" names hidden, side-street names
  from zoom 16 (`0e5e740`).
- **`m-cycle` merged into `main`** (fast-forward) and **the CMS redeployed** —
  the live `main.dart.js` matches the build.
- **Content published by the user** (dry run, then publish, both at `0e5e740`):
  pack `20261001154404` is live (38 eras, 237 events, `order` kept for old
  builds); the street geometry and the 37 MB base map are on the CDN under
  their versioned addresses.
- **App bundle 1.1.0+7 built** (79.6 MB, signed with the upload key; `1dd4565`).

**Carried forward (all wait on the user):**
1. Upload `1.1.0+7` to the Play closed-testing track, and try a **release**
   build of the street map on a phone (only debug builds have been seen there;
   release decodes map tiles differently).
2. Firestore (still off): steps in `979cb3f:EXECUTION.md`, plus the updated
   `firestore.rules` (public read of `events/`).
3. The Play closed test (12+ testers, 14 days), Analytics custom definitions,
   the privacy page and Data safety form, Cycle E's items, optionally deleting
   `admin-long-ky.web.app`.

## Cycle Q — what the user asked for

> The splash screen is a bit boring. It's just our logo in the center with the
> black-ish blank background. Use Higgsfield to give us a more interesting
> splash screen.

### What I checked (read-only)

- **Today's splash** is `SplashGate` (`apps/mobile/lib/screens/splash/
  splash_gate.dart`): the seal (184 px, soft gold halo) on a dark radial
  gradient, the "Long Ký" wordmark in Playfair, a short rule, "NGHÌN NĂM SỬ
  VIỆT", and a thin progress bar that appears only if media is still warming
  after ~2 s. It stays up 2–8 s (content check + Home media warm-up), so
  whatever we put behind it is really seen, not flashed.
- **Before Flutter draws, Android shows its own launch window**, and ours is
  the stock template: `Theme.Light` with `?android:colorBackground` — a **white
  flash** on phones in light mode, then the dark splash. (Android 12+ also puts
  the launcher icon in the middle of that window.) Fixing it belongs in this
  cycle: a nicer splash that opens with a white blink undercuts it.
- The art rules that apply (from earlier cycles): painterly-realism sơn mài
  look, never cartoon; full-bleed, no frame or panel; **no text, letters,
  signatures or Hán tự anywhere**; static unless the user asks for motion; and
  every image reviewed before it ships.
- **No map of Vietnam** in the art: a country outline drags in the island-chain
  question the street map's sovereignty guard exists to avoid.

### The steps

**Q-1 — Generate the background art** (needs credits; ~2 per image).
- `nano_banana_pro`, **9:16 portrait**, 2k. Several variants (Q4), so there is
  a real choice.
- **Composition is the hard requirement:** the middle band — where the seal and
  wordmark sit, roughly 25–70 % of the height — must be calm and dark (open
  sky, mist, plain lacquer ground). Detail lives at the top and bottom edges
  and the sides. A busy centre would fight the logo.
- Prompts carry the standing rules: the painterly-realism style lock, the
  full-bleed / NOT-a-panel clause, no text / letters / signature / Hán tự, no
  modern objects, a palette that matches the seal (oxblood, black lacquer, gold
  leaf, a touch of eggshell).
- **Every variant reviewed before the user sees it:** style, frame or margin,
  stray text or signatures in corners, garbled patterns, and how it looks with
  the seal and wordmark on top (a mock-up, not the bare image).

**Q-2 — The user picks one** from a side-by-side sheet of mock-ups (art + seal +
wordmark as the phone would show them). Nothing goes into the app until then.

**Q-3 — Put it in the app.**
- Bundled with the app (`assets/brand/splash-bg.webp`), not on the CDN: the
  splash shows before the network or the media cache are ready. WebP q85 at
  about 1080×1920 (expected 200–400 KB). The PNG original goes to
  `brand/splash/`.
- `_SplashScreen` draws it full-screen (`BoxFit.cover`, anchored to the centre,
  so taller or wider phones crop the edges, never the middle), with a soft dark
  vignette behind the seal and wordmark so they stay crisp on any art. The seal,
  wordmark, kicker and progress bar stay as they are.
- The art is decoded before the splash's first frame (`precacheImage`) and
  fades in with the seal, so it never pops in late.
- Motion per Q2.

**Q-4 — Fix the native launch window** (Q3). `LaunchTheme` gets the lacquer
colour as its background (light and night variants alike), and on Android 12+
`windowSplashScreenBackground` gets the same colour with the seal as its icon.
Launch then reads: dark ground with the seal → the Flutter splash fades the art
in around the same seal. No white blink.

**Q-5 — Tests.**
- The splash asset is declared and loads.
- `_SplashScreen` (made testable) renders the art, the seal and the wordmark
  with no exceptions, at a tall phone size and a short one.
- With "reduce motion" on, the drift is off (only if Q2 adds motion).
- The usual sweep: mobile tests, analysis.

**Q-6 — See it on the phone** — a release build, cold start, with the phone in
light and in dark mode: no white flash; the art crops well on a 20:9 screen;
the seal and wordmark read clearly; the splash still lifts on time.
Screenshots to the user.

**Q-7 — Commit** on `main` and update this file.

### Scope notes

- **Not in Q:** a new logo or wordmark (both stay); the iOS launch screen (iOS
  is not set up); a video splash (opt-in only, per the standing rule).
- Cost: about 2 credits per image — 3 variants ≈ 6 credits, more if one fails
  review and is re-rolled.

## Decisions for the user

- **Q1 — What the art shows.** Recommend **A, the bronze drum (trống đồng
  Đông Sơn) face**: its concentric rings of flying birds and patterns in gold
  leaf on black lacquer, its star at the centre — with the seal sitting right on
  that star. It is the oldest emblem of Vietnamese history (some 2,500 years),
  "nghìn năm sử Việt" in one image, and naturally calm at its centre.
  Alternatives:
  - **B — A gold dragon among clouds** around the edges of the screen, echoing
    the Nguyễn dragon in the seal. A strong brand tie, but it risks looking busy
    and repeats the seal's own motif.
  - **C — A dawn landscape:** limestone karst peaks (Tràng An / Hoa Lư, the
    first capital) over a misty river, a lone boat, gold light. The most
    scenic, the least symbolic.
- **Q2 — Motion.** Recommend **a very slow drift done in code** (the art scales
  ~3 % and pans slightly over the splash's few seconds; off when the phone asks
  for reduced motion). It costs no credits and stays a still image.
  Alternatives: fully static (the standing default), or a Kling video loop
  (~7.5 credits and a few MB in the app — not recommended for a splash).
- **Q3 — The native launch window.** Recommend **fixing it in this cycle**
  (dark ground plus the seal), since today's white blink would undercut the new
  splash. Alternative: leave it.
- **Q4 — How many variants.** Recommend **3 of the chosen direction** (~6
  credits). Alternative: 1 each of A, B and C (~6 credits), to choose the
  direction by eye rather than by description.

## Next cycles (queued — not to be planned until the user says)

More landmarks; an in-house lacquer base-map style; the first standalone
events; streets near me; more cities; a CMS editor for street mappings and
landmarks; pages for famous streets with none yet; street mapping over the air;
the carried-over UX audit findings (`21fb88b:EXECUTION.md`).
