# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: PLANNING Cycle I (CMS: retire legacy Portraits, inline image/video
replace on the Era, Period and People pages). Nothing built yet. Three
decisions (I1–I3) need the user before execution.**

## Audit of the previous plan (before adding Cycle I)

**Everything Claude owned is done.**
- Cycle H: shipped in `0bddd08`.
- The four live-feedback fixes after it:
  - Preview removed; Appearance settings (light/dark/auto plus an accent
    colour) with a neutral hand-built colour scheme instead of the pink
    `fromSeed` derivation — `d211289`.
  - Invisible icons and unresponsive Appearance clicks — `0e10f42`.
  - The Appearance entry clipped off in short windows, now a single `⋮`
    menu — `6751575`.
- The only open item from the user's last check: confirm that the `⋮` menu
  shows and the theme options respond.

**Still open, in the user's hands (unchanged, none of it blocks Cycle I):**
1. Firebase console → Analytics → Custom definitions: register
   `era_slug`, `event_id`, `figure_id`.
2. Deploy the privacy page (the portfolio site is a single-page app, so
   `curl` gets a 200 for any route and can't confirm it's live). Make Play
   Console's Data safety form match
   `docs/play-store/data-safety-and-listing.md` before uploading 1.0.1+3.
3. Upload the 1.0.1+3 `.aab`.
4. From Cycle E: payments verification, the `long_ky_tea*` products,
   license testing, a test purchase, screenshots and the feature graphic.
5. Optional: delete the unused Hosting site `admin-long-ky.web.app`. It
   still exists (checked with `firebase hosting:sites:list`).

**Known caveat, not a task:** an era with `draft: true` is kept out of
over-the-air packs but would still ship in a fresh mobile *build*. Clear
`draft` before cutting a release.

## Facts Cycle I is built on (checked, not assumed)

- **Legacy Portraits: 17 people**, all portrait-only; no person mixes
  portrait with avatar/full body.
  - Hồng Bàng (7): Kinh Dương Vương, Lạc Long Quân, Âu Cơ, Vua Hùng, Sơn
    Tinh, Thủy Tinh — plus An Dương Vương, whose sheet lives in this
    folder.
  - Âu Lạc (5): Cao Lỗ, Thần Kim Quy (a turtle), Mỵ Châu, Trọng Thủy,
    Triệu Đà.
  - Nhà Triệu (5): Triệu Văn Đế, Lữ Gia, Cù Thị, Triệu Ai Vương, Triệu
    Kiến Đức.
  - Each sheet is **1254×1254**, 3 panels: full body on the left half,
    bust top-right, action pose bottom-right.
  - Modern art for comparison: avatar **2048×2048** (1:1), full body
    **1696×2528** (2:3).
  - No era overrides a character's image (`characters[]` carries no
    portrait/avatar/fullBody), so switching a person switches them
    everywhere.
- **Where Portrait is used in the app:**
  - `event_figures.dart` crops the bust from the sheet when there's no
    avatar.
  - `character_detail_screen.dart` crops the full body from the sheet when
    there's no fullBody.
  - Every shipped app version already prefers `avatar`/`fullBody`, so
    giving these 17 people dedicated art works on phones already installed.
- **Cropping the old sheets isn't good enough:**
  - The full-body panel is about 627×1254, a 1:2 shape rather than 2:3.
  - The bust is about 550 px wide, a quarter of a modern avatar.
  - The sheets have the margin problem that retired this format in the
    first place ([[character-sheet-bust-crop]]).
- **Era imagery:**
  - 38 covers, 84 scene layers, 237 event hero images.
  - All 17 periods have a cover.
- **Video:**
  - Two looping `.mp4`s exist, on the **sky scene layer** (`scene.layers[].video`),
    not the cover: Điện Biên Phủ and Đại thắng mùa Xuân.
  - Publishing copies them as-is (no WebP conversion); both are in the
    manifest.
- **CMS gap:** `collectMediaRefs` only reads `flagship`/`reduced`, so **the
  two `.mp4`s don't appear in the Media library at all** today.
  - The replace flow decodes files with `instantiateImageCodec`, which
    can't read a video.
  - The Worker already accepts `video/mp4`, up to 100 MB.

## Decisions needed

- **I1 — How the 17 get avatar and full-body art.** *Recommend: regenerate
  with Higgsfield* (nano_banana_pro).
  - Two single-subject images per person: 1:1 avatar and 2:3 full body.
  - Painterly lacquer realism, prompts faithful to the chronicle
    ([[stay-close-to-dvsktt]], [[art-style-painterly-realism]]).
  - **The existing sheet goes in as the reference image**, so each figure
    keeps their current look.
  - Cost: 34 images at about 2 credits each, around 70 credits plus
    retries.
  - Alternative: crop the old sheets. That's free but low-res, the wrong
    shape, and keeps the margin artefacts. Not recommended.
- **I2 — What happens to `portrait` afterwards.** *Recommend:*
  - Remove the field from those 17 people once their new art is published.
    The old sheet stays in `long-ky-sources` as the original, and the next
    publish drops it from the CDN.
  - Keep `portrait` optional in the schema and keep the app's fallback
    code. Both are harmless, and ripping them out means a mobile release
    for no user-visible gain.
  - The CMS then shows a Portrait slot only on a person who still has one.
- **I3 — Video scope for inline editing.** *Recommend: replace an existing
  `.mp4` only.*
  - Also show the video on its layer and include it in the Media library.
  - Defer "add a looping video to a layer that has none": it changes the
    JSON and is a creative call per era.

## Cycle I — spec

### I-0 Housekeeping

- The Media library indexes `video` paths too, so the two `.mp4`s appear,
  grouped under their era as "Scene layer N — video".
- Record the post-H fixes in this file (done above).

### I-1 Shared inline media slot (the foundation for I-2 and I-3)

- **`MediaSlot` widget**, one per asset path:
  - Thumbnail: from the CDN for images; a muted looping preview for
    `.mp4`.
  - Pixel dimensions (and duration for video), and file size.
  - A status badge: *Published*, *Missing* (referenced but never
    published) or *Replaced — publish to go live*.
  - A **Replace…** button (it reads **Upload…** when the file is missing)
    and a small "Open in Media library" link.
- **`MediaReplaceDialog`**: the current replace dialog moved out of
  `media_library_screen.dart`, unchanged in behaviour, so the Media
  library and every page share one flow. Kept as-is:
  - The file must match the path's type.
  - Old and new side by side.
  - Warnings for a changed aspect ratio, a smaller image, or lost
    transparency.
  - The Worker backs up the old original before overwriting it.
- **Video in the replace flow** (adds the `video_player` package):
  - Dimensions and duration come from the video player instead of the
    image decoder.
  - Warnings for a changed aspect ratio or lower resolution; files over
    100 MB are refused up front.
- **"Replaced this session" moves into a shared provider.** Today it's a
  map private to the Media library. As a provider, replacing an image on
  the People page also updates the Media library, the Era page and the
  Period pane (and vice versa).
- If an asset's `flagship` and `reduced` point to *different* paths, show
  one slot per path. Today they're always identical, so users will see one
  slot.

### I-2 Images on the Era page and the Period pane

- **Era page** (`/eras/:slug`): add an **Images** tab next to Guided and
  Raw JSON.
  - **Cover** slot.
  - **Scene layers** in depth order: each image layer's still, plus its
    video slot when it has one. Particle and gradient layers are listed as
    non-image rows so the order still reads correctly.
  - **Event heroes**: one row per event in timeline order, showing the
    event title and its hero slot. Events with no hero say so.
- **Period pane** (in the Content tree): a **Cover** slot under the fields.
- Images are replaced at the same path, so none of this changes the JSON.
  There is nothing to commit, only a publish to take it live.

### I-3 Inline replace on People

- Avatar / Full body / Portrait become `MediaSlot`s, with inline Replace
  (or Upload) on the page.
- **"Add avatar" / "Add full body"** for a person who has neither.
  - This creates the asset ref at the conventional path
    `eras/<first era in "Used in">/characters/<id>-avatar.png` (or
    `-full.png`), then opens Upload.
  - It is a JSON change, so it gets staged for commit like any other edit.
  - It's how a future person gets art without touching raw JSON.

### I-4 Replace the 17 legacy Portraits (after I1 and I2 are confirmed)

1. **Generate**, one era at a time. For each person: the 1:1 avatar and
   2:3 full body, with the old sheet as the reference image.
   - Thần Kim Quy's avatar is the turtle's head; the full body is the
     whole turtle.
   - Checks: a full-bleed image, no text or borders, the correct era
     dress per the chronicle.
2. **Review gate (the user):** Claude publishes a contact sheet for each
   era — old sheet next to the new avatar and full body. Nothing goes into
   `content/` until the user approves each era. Rejected images are
   regenerated.
3. **Wire in** approved art:
   - Save as `eras/<era>/characters/<id>-avatar.png` and `-full.png`.
   - Upload with `push_sources.sh`.
   - Update `people.json`: add `avatar`/`fullBody`, remove `portrait`
     (per I2).
   - Validate, dry-run publish, then a **real publish with the user's
     yes**.
4. **Verify on the phone** (the user, Android): figure tiles and the
   character detail hero for these 17 no longer look cropped from a sheet.

### I-5 Verify and ship

- **Tests:**
  - `collectMediaRefs` includes video paths.
  - `MediaSlot` states: published, missing, replaced, video.
  - The shared replaced-media provider updates every page that uses the
    same path.
  - "Add avatar" writes the conventional path, and only its own person.
  - `melos analyze` and the full test suites stay green.
- **Browser:**
  - Claude checks that the build loads with no console errors.
  - This session's Browser pane has shown stale renders, so the visual
    check goes to the user and is not claimed as verified.
- **Deploy** the CMS with `firebase deploy --only hosting:long-ky-admin`.
  The Worker needs no change for this cycle.

### Out of scope for I

- Adding a new looping video to a layer that has none (deferred per I3).
- Removing `portrait` from the schema or app code (per I2).
- A per-event field editor. Event text stays in the era page's Raw JSON;
  only the event *hero image* becomes editable here.

## Next cycles (queued)

Carried-over UX audit findings (top-bar scrims, particles over text, Chào
cờ lyrics legibility, swipe-hint timing) are still parked — see
`21fb88b:EXECUTION.md`.
