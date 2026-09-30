# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: PLANNING COMPLETE — Cycle N (events independent of eras). All
decisions are confirmed: N-D1–N-D3, and N1–N6 as recommended (2026-09-30).
N7: the Worker is on **Workers Free**, so the CMS one-subrequest content load
is step 1 and **blocks merging `m-cycle`**. Nothing in N is built; the next
step is an EXECUTION session.** Cycle M's full spec is at
`cfa220a:EXECUTION.md`.

## Audit of the previous plan

**Cycle M is code- and data-complete on branch `m-cycle`** (not merged, no PR):
- **M-A:** the street tools, matcher, geometry, validator rules and tests.
  - Real data: `hcm-boundary.geojson` (as of 2025-06-01) and `hcm.json`, with
    **92 streets, all approved**: 74 exact matches, plus 18 alias or
    multi-target rows the user approved on 2026-09-30.
  - `hcm-streets.geojson` is generated (75 KB, 3,145 points), git-ignored,
    and validated.
- **M-C/M-D:** the `/duong-pho` screen, the Sảnh entry, the reverse chip and
  the About note. It was checked in a web build against a fixture.
- **Fixed while running on real data:**
  - OSM spells some names with the look-alike **Ð (U+00D0)**; Đồng Khởi was
    invisible because of it. Names are now folded to Đ and NFC-normalized
    (`f4322a2`).
  - The download is tiled and resumable.
  - The geometry now goes to `content/streets/`.
- **Deviations:**
  - The basemap uses Protomaps' stock dark theme, not an in-house style.
  - The street mapping ships bundled, not over the air.
  - The 74 exact matches are name-only and were not hand-checked.

**Cycle M, still open (the user's):**
1. **Do not merge `m-cycle` until N step 1 has shipped.** The Worker is on
   Workers Free (confirmed 2026-09-30). M takes the CMS content load from 50
   to 52 subrequests, past the limit of 50.
2. Run `tool/push_sources.sh` (it uploads `hcm-streets.geojson`), then the
   normal publish: dry run, the user's yes, the real publish.
3. The PMTiles extract, its R2 upload, and the r2.dev `Range` check. Until
   then `STREET_BASEMAP_URL` is empty, and the map shows gold streets on a
   plain ground. The basemap has not been visually verified.
4. A new app build.

**Still open from before** (unchanged, carried forward):
1. **Turn Firestore on.** The steps are in `979cb3f:EXECUTION.md`. Note N4:
   Firestore's layout changes in this cycle, and doing that before it's
   enabled is free.
2. **Build and upload a new app version.** 1.0.2+4 was never uploaded, so
   J, K, M and N all ride on the next build.
3. **Play closed test:** 12+ testers opted in for 14 days straight.
4. **Firebase → Analytics → Custom definitions:** `era_slug`, `event_id`,
   `figure_id`.
5. **Privacy page:** deploy it, and make Play's Data safety form match it.
6. **From Cycle E:** the `long_ky_tea*` products, license testing, a test
   purchase, screenshots, and the feature graphic.
7. **Optional:** delete the unused Hosting site `admin-long-ky.web.app`.

## Cycle N — what the user asked for

> If an event is not in an era yet, we can simply create a standalone event.
> Make events separate from eras and periods.

**Confirmed (2026-09-30):**
- **N-D1: approach B, the people pattern.** Events live in one registry, and
  eras reference them. An event that no era references is standalone.
- **N-D2: at most one era per event.** An event is in one era or in none.
- **N-D3: a standalone event's own `citation` is enough.** It needs no era
  `primarySource`; every event still must have a citation.

Periods need no work. Events never pointed at a period; they get one only
through their era.

### What I measured (2026-09-30, `m-cycle`)

- **Volume:** 237 events across 38 eras, 4–11 per era.
  - Every event has a `hero` and a `citation`; 236 have `figureIds`.
  - Only 12 use `relatedEventIds`.
  - Heroes are stored under `eras/<slug>/events/…`.
- **Six events have no `year.value`.** All six are legends: `no-than-kim-quy`,
  `my-chau-trong-thuy`, `lac-long-quan-au-co`, `thanh-giong-pha-giac-an`,
  `banh-chung-banh-giay`, `son-tinh-thuy-tinh`.
- **Size:** all events together are **989,344 bytes** as compact JSON. The
  canonical pretty-printed file is larger. `people.json` is 305 KB.
- **Firestore's limit is 1 MiB per document** (1,048,576 bytes; firebase.google.com
  › Firestore › Quotas). So all events **cannot be one Firestore document**,
  the way `people.json` is today.
- **Cloudflare Workers Free allows 50 subrequests per request** (Paid allows
  10,000; developers.cloudflare.com › Workers › Limits). The CMS content load
  (`services/cms_api/src/github.ts:63-104`) makes one GitHub request per
  `content/**/*.json` file, plus 3 more.
  - On `main` that is 47 + 3 = **50, exactly the Free limit.**
  - `m-cycle` adds two files, making **52**.
  - I don't know which plan this Worker is on.
- **Installed-app contract:**
  - The app parses each era with `Era.fromJson`, which **requires an integer
    `order` on every event** (`history_event.dart:101`).
  - `ContentPack` reads only the keys it knows, so extra top-level keys are
    ignored (`content_pack.dart:59-77`).
  - The pack schema gate is `kSupportedPackSchema = 1`.
  - So a pack that keeps events **inlined inside each era, with `order`**,
    still parses on any build already out.
- **Everything that assumes an event has an era:**
  - Route `/era/:slug/event/:id` and its 6 call sites.
  - The event page's palette, backdrop, figures, "section" line, "3 / 12"
    counter, and cross-era pager.
  - `eventsWithFigure` and `relatedEventsFor`, both era-scoped.
  - The global timeline, which groups by era.
  - The quiz's `(era, event)` pairs and its "which era?" question.
  - Media prefetch.
  - Route telemetry (`event_detail` with `era_slug` + `event_id`).
  - Street targets, which carry an era.
  - The CMS: `addEvent`, `updateEvent`, `deleteEvent`, `reorderEvent`,
    `eventsReferencing` and `ensureInRoster` (all per era), `EventDialog`
    (roster-based figure picker), the era editor's Events tab, the content
    tree, and `media_refs`.
  - The validator: figures must be on the era's roster, related events must
    be in the same era, and `order` must be a contiguous 0..n-1 run per era.

### N-A — the data model

- **Registry:** events live in `content/events.json` (N1) plus
  `content/event.schema.json`. Each event keeps every field it has today
  **except `order`**. Eras switch to `events: [{"ref": "<id>"}, …]`, and the
  list order *is* the reading order.
- **Standalone** means no era references the event.
- **Media:** hero paths don't move, since a path is only a string. New
  standalone events use `events/<id>/…`.
- **Domain code:**
  - an `EventRegistry` modeled on `PeopleRegistry`;
  - `Era.fromJson` accepts **both** an inlined event and a `{ref}` item. That
    one parser serves the bundled files (refs) and the pack or Firestore
    (inlined).
  - `Era.order` for each event becomes its index in the list.
- **Validator rules (all tested):**
  - event ids are unique;
  - every `ref` resolves;
  - an event is referenced by **at most one** era (N-D2);
  - an era has at least one event (`minItems: 1` stays; N5);
  - every event has a `citation` (N-D3), and the schema already requires it.
  - **Standalone events** must have a `year.value` and a `hero` (N5). Their
    `figureIds` must be people who appear on at least one era roster (N3).
  - **In-era events:** `figureIds` must be on that era's roster, as today.
  - `relatedEventIds` may point across eras and at standalone events.
  - The street validator follows the new event model.

### N-B — the migration (one script, text unchanged)

`tool/migrate_events.dart` moves every event out of the 38 era files into
`events.json`, replaces each era's list with refs, and drops `order`.

It then verifies itself: it rebuilds every era with events inlined and
re-numbered `order`, and requires that output to be **byte-identical** to the
canonical pre-migration era file. The script runs once; it is committed for
the record, and rerunning it is a no-op.

### N-C — publishing (no change for installed apps)

- **`build_content_pack.dart`:** the pack keeps the same shape and
  `schemaVersion: 1`.
  - Each era keeps its events **inlined, with `order`**, so every existing
    build parses it.
  - A new top-level `standaloneEvents` key is ignored by old builds and read
    by new ones.
- **`publish_firestore.mjs`** (N4):
  - era documents are written **inlined**, as now;
  - each standalone event gets its own document in an `events/<id>`
    collection.
  - A cold start reads 40 documents plus the standalone count, instead of
    237 + 40.
- **`gen_media_manifest` and `media_ledger`** also walk `events.json`.
- **CI** (`content-check.yml`) runs the new validator rules.

### N-D — the app

- **Content source:** `ContentSource` gains `loadEventsJson()`. The bundled
  source reads `events.json`; the pack and Firestore sources serve the
  standalone events. `ContentRepository` exposes the registry and
  `standaloneEvents()`.
- **Route (N2):** `/su-kien/:id`.
  - An in-era event **redirects** to `/era/:slug/event/:id`, so existing links
    and analytics keep working.
  - A standalone event opens a new page.
  - Every internal link that only knows an event id (streets, quiz, related
    events) uses `/su-kien/:id`.
- **Standalone event page:** the same body, pull-quote, citation and figures
  as an in-era event.
  - Its look is a neutral lacquer ground with a gold accent and the event's
    own hero, since there is no era scene.
  - It has no "3 / 12" counter and no pager (N6).
  - Figure chips link to each person's **home era** (the earliest era by
    `order` that lists them), the same rule the streets use.
- **Global timeline:** standalone events appear as their own nodes, placed by
  `year.value` (N6). Search covers them too.
- **Quiz:** standalone events join the year, who, quote and order questions.
  They are excluded from "which era?".
- **Character page:** a short "Cũng xuất hiện trong" row lists standalone
  events featuring the person. `eventsWithFigure` stays era-scoped for the
  main list.
- **Street map:**
  - `StreetTarget.era` becomes optional for events;
  - `routeForTarget` uses `/su-kien/:id`;
  - the reverse chip works on standalone pages.
  - `hcm.json` is re-validated; no mapping changes.
- **Telemetry:** `/su-kien/:id` logs as `event_detail` with `event_id`, and
  `era_slug` only when the event has an era.
- **Tests:**
  - dual-mode `Era.fromJson`;
  - registry resolution;
  - the redirect;
  - the standalone page;
  - timeline placement;
  - quiz exclusion from "which era?";
  - the pack still parsing on the current parser (a golden test against
    today's `ContentPack`).

### N-E — the CMS

- **A new Events screen:**
  - lists every event, filterable by era, "standalone", or text;
  - creates a standalone event;
  - edits an event;
  - moves an event into an era, or out of one (it then becomes standalone;
    it is never deleted).
  - Delete lists and cleans every reference: its era, `relatedEventIds`,
    and street targets.
- **Era editor, Events tab:**
  - add an existing standalone event or create a new one;
  - reorder;
  - remove from the era (the event becomes standalone).
- **`EventDialog`:**
  - For an in-era event, keep today's roster auto-add.
  - For a standalone event, pick from people who are on some roster (N3).
- **`ContentDraft.validate()`**, the content tree and `media_refs` learn
  about `events.json`.
- **Content load: one subrequest (N7).** Replace the per-file blob fetches
  with **one** request that returns every `content/**/*.json` text.
  - The candidate is a single GitHub GraphQL query:
    `object(expression: "main:content")` with its nested tree entries' blob
    `text`.
  - A spike checks that it works first. It must return every file untruncated
    (`isTruncated` must be false for all files, including `events.json` at
    about 1 MB). If it doesn't, the fallback is the repo tarball, with its
    CPU cost measured.

### Scope notes

- **Out of scope:**
  - writing any new standalone events (content, done later in the CMS);
  - an event in two eras (ruled out by N-D2);
  - a pager across standalone events;
  - Home changes. Home stays an era stack, so standalone events are not on
    Home.
- **What ships over the air:** the data migration is invisible to installed
  apps. Standalone events and `/su-kien/:id` need **the next app build**.
- **Order:**
  - N7's CMS fix comes first (the Worker is on Free).
  - Ideally Firestore is enabled **after** N lands (the layout changes).
  - Cycle M merges **before** N. N then rebases, and the street event
    targets simplify.

## Decisions (N1–N6 confirmed as recommended on 2026-09-30; N7 answered: Free)

- **N1: storage. Confirmed: one `content/events.json`,** like `people.json`.
  - For: one file to load, validate, bundle and index. The Firestore size
    limit doesn't matter, because Firestore stores it split (N4). Git diffs
    stay line-based because the file is canonically formatted.
  - Against: a ~1 MB file that the CMS rewrites whole on every edit.
  - Alternative: one file per event (`content/events/<id>.json`). That
    scales better, but adds 237 files, needs an index listing them, and would
    make N7 mandatory even on Workers Paid.
- **N2: address. Confirmed: `/su-kien/:id` for every event**, redirecting
  in-era ones to their era route.
  - Alternative: `/su-kien/:id` for standalone events only. Links then still
    need to know an event's era.
- **N3: standalone events' figures. Confirmed: only people on at least one
  era roster,** so every figure chip opens a page.
  - Alternative: allow anyone in `people.json`. A person with no era shows
    as a plain name with no link.
- **N4: Firestore layout. Confirmed: eras inlined, plus `events/<id>` for
  standalone events only.** This keeps reads per cold start at about 40.
  - Alternative: all 237 events as documents. That is 237 more reads per
    cold start against the daily free quota (I have not measured traffic).
- **N5: validation. Confirmed:**
  - standalone events need a `year.value` and a `hero`;
  - an era keeps at least one event.
  - The six undated legends already sit in eras, so they're unaffected.
- **N6: timeline placement. Confirmed:** a standalone event shows as its
  own node, **right after the era group whose `startYear` is the latest one
  ≤ its year**, marked "Sự kiện riêng". Its page has no pager.
  - Alternative: a separate "Sự kiện riêng" section at the end.
- **N7: the Cloudflare Workers plan — answered: Workers Free.** So the
  one-subrequest content load (N-E) ships **first**, before `m-cycle` merges,
  because M takes the load from 50 to 52 subrequests.

## Execution order

1. **CMS one-subrequest content load** (the Worker is on Free): a spike of
   the GraphQL query, then the implementation, then a test against the real
   repo, then deploying the CMS. Only then merge `m-cycle` into `main`.
2. **N-A:** schema, `EventRegistry`, dual-mode `Era.fromJson`, validator
   rules, tests.
3. **N-B:** the migration script, the byte-identical round-trip check, and
   one migration commit.
4. **N-C:** pack builder, Firestore publisher, media walkers, CI. Includes
   the golden test showing today's parser accepts the new pack.
5. **N-D:** app changes, tests, and a check in a web build at localhost.
6. **N-E:** CMS screens and dialog, the draft validator and media refs, and
   deploying the CMS.
7. **Publish:** dry run, the user's yes, the real publish. The app side
   waits for the next build.

## Next cycles (queued)

- **Streets near me** (deferred from M). It needs "while using the app"
  location permission (on-device only), a Play Data safety update, and a
  "Gần tôi" button.
- **More cities:** Hà Nội first, then Huế and Đà Nẵng. The M-A tools take a
  city argument.
- **A CMS editor for street mappings** (approve, re-target, add aliases).
- **Content cycle for famous streets with no page yet:** Nguyễn Hữu Cảnh,
  Lê Hồng Phong, Võ Thị Sáu, Phan Văn Trị, Nguyễn An Ninh, Hoàng Văn Thụ,
  Trần Văn Giàu. After N, a street can also point at a standalone event.
- **Street mapping over the air** (it ships bundled today).
- **Media manifest live via Firestore** (carried over from K5).
- **Carried-over UX audit findings:** particles over text, Chào cờ lyrics
  legibility, swipe-hint timing. See `21fb88b:EXECUTION.md`.
