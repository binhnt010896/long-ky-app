# Plan: content feedback, AI disclaimer page, iOS App Store

Planned 2026-10-05. **Parts 1 and 2 are built (2026-10-06)**; Part 3 (iOS) is not started.

**Locked decisions (user, 2026-10-06), so "Execute feedback-disclaimer-ios-plan.md" builds Parts 1 and 2 as written:**
- **Delivery:** the mail-app (`mailto:`) version. v2 (in-app sending through the Cloudflare
  Worker) is **not** built.
- **Recipient:** `binhnt.010896@gmail.com` for now. It goes in **one constant**
  (`kFeedbackEmail`), used by both the feedback sheet and the disclaimer page, so switching
  later (for example to `longky@binh-nt.dev`) is a one-line change plus a release.
- **Scope of "Execute":** Parts 1 and 2 only. Part 3 (iOS) needs your Apple Developer
  enrolment and Xcode first, so it waits until you ask for it separately.

## 1. "Report a mistake" on every detail page

**Where:** a quiet icon button in the top bar of the four detail screens. It sits next to
the VI/EN toggle, with no pill and no badge ([delicate-ui-no-nags]).
- Era figure: `character_detail_screen.dart`
- Standalone person: `standalone_character_screen.dart`
- Era event: `event_detail_screen.dart`
- Standalone event: `standalone_event_screen.dart`

Label: "Báo sai sót" / "Report a mistake".

**Flow:**
1. A small bottom sheet opens. It asks *What looks wrong?*, with three choices:
   - Hình ảnh / Image
   - Nội dung / Text
   - Khác / Other
2. The reader can add an optional note, then taps **Gửi email / Send email**.
3. The phone's mail app opens a draft (`mailto:`) addressed to you, already filled in:
   - Subject: `[Long Ký] Báo sai sót: <title> (<event|person> <id>)`
   - Body:
     - the reader's choice and note,
     - the page (route),
     - the content-pack version,
     - the app version and platform,
     - the language.

     That's everything you need to find the item in the CMS.

The reader sends it from their own mail app. We store nothing, and there's no backend.

**Fallback:** if no mail app opens (some browsers and desktops), the sheet shows your
address and a **Copy** button for the prepared message.

**Optional v2, if mailto feels clunky:** send in-app through the existing Cloudflare Worker
(`services/cms_api`).
- It would use a new public `POST /feedback` route and Cloudflare Email Routing's
  `send_email` binding. That binding can deliver to a verified address (yours) for free,
  now that `binh-nt.dev` is on Cloudflare.
- It needs rate limiting (per IP) and a size cap, plus Turnstile on web.
- The reader would never see your address, and no mail app is needed.

**Also:**
- Telemetry event `feedback_opened {type, id}`, with no message text.
- One line in the privacy policy about feedback emails.
- Tests:
  - the button is on all four screens,
  - the `mailto` URI is built and encoded correctly, including the Vietnamese subject,
  - the fallback works when the launch fails.

## 2. Disclaimer page: "Lưu ý về hình ảnh & nội dung"

**Route:** `/luu-y` (title "Lưu ý về hình ảnh & nội dung" / "About images & content").

**Reached from:**
- the Sảnh list, next to *Về Long Ký*;
- a link at the end of the About page's *Hình ảnh* section;
- a small ⓘ beside the image caption on detail pages (the caption already says
  "Minh họa · phong cách sơn mài" on painted art).

It's never shown as a pop-up or on first launch.

**Text** (vi + en, short):
- **Many images are made with AI.** Portraits and scenes of people from before photography
  are AI-generated illustrations in a lacquer-painting style. They are based on what the
  chronicles describe, and are **not** real likenesses: no portrait of these people survives.
- **Archival photographs are restored with AI help.** For people who were photographed,
  we start from a real photo. Colour, sharpness, framing and the background are
  reconstructed, so details may differ from the original. Where a photo was too damaged
  to restore faithfully, we show a blank portrait instead of inventing a face.
- **The text follows the cited sources** (see *Nguồn sử liệu*), but mistakes are possible.
- **Seen something wrong?** Tap *Báo sai sót* on that page, or email `kFeedbackEmail`
  (currently `binhnt.010896@gmail.com`).

**Tests:** the route renders in both languages, and every entry point opens it.

## 3. Releasing on the Apple App Store

**There is no "12 testers for 14 days" rule on Apple.** That is Google Play's requirement,
and only for *personal* Play developer accounts created since late 2023. Apple's path:

1. **Enroll in the Apple Developer Program.** It costs US$99 a year, as an individual or
   an organisation. You need an Apple ID with two-factor authentication and identity
   verification (the Apple Developer app). It usually takes 1–2 days.
2. **Upload a build and submit it for App Review.** Most reviews finish within 24–48 hours.
   A first app often gets one rejection round for small fixes.
3. **TestFlight is optional.** Internal testers (up to 100 on your team) need no review.
   External testers need a short beta review. No minimum testers, no minimum days.

**What this app still needs for iOS** (it has never been built or run on iOS):
- **Build machine.** Xcode on your Mac, which isn't installed yet. Or a cloud build, such
  as Codemagic's free tier or GitHub Actions macOS runners.
- **Signing.**
  - The bundle ID is already `app.longky`.
  - It needs a signing certificate and a provisioning profile.
  - It needs an App Store Connect app record.
- **Firebase.** Add an iOS app to the Firebase project (`GoogleService-Info.plist`).
  Analytics and Crashlytics are only configured for Android today.
- **Icons and launch screen.** iOS app icons (`flutter_launcher_icons` has `ios: false`),
  plus the launch screen.
- **In-App Purchase tips.**
  - `tip_store.dart` already uses StoreKit through `in_app_purchase` and frames them as
    tips, not donations, which follows guideline 3.1.1.
  - Still to do:
    - create the 3 consumables (`long_ky_tea`, `_2`, `_3`) in App Store Connect,
    - sign the **Paid Apps agreement**,
    - fill in banking and tax details, which Apple requires even for tips.
- **Privacy and compliance.**
  - App Privacy labels: Analytics and Crashlytics, usage and diagnostics data, not linked
    to identity.
  - Privacy policy URL: done.
  - Privacy manifest: the Flutter and Firebase plugins ship theirs.
  - Export compliance: HTTPS only, so `ITSAppUsesNonExemptEncryption = NO`.
- **Store listing.**
  - Screenshots for 6.9″ and 6.5″ iPhones.
  - Either iPad screenshots, or iPhone-only at first to skip them.
  - Age rating questionnaire: war history, likely "Infrequent/Mild Realistic Violence".
  - Description and keywords.
- **Storefronts.** Consider leaving out mainland China. Apps there now need a Chinese
  ICP filing, and a Vietnam-POV history app is a review risk there.
- **Expect some iOS-only fixes** the first time it runs. Likely spots: `video_player`,
  StoreKit, `path_provider`, and the Firebase setup. This is the first iOS build.

**Rough timeline:**
- Enrollment: 1–2 days.
- iOS setup and the first build: about 1–3 working days between us.
- Review: 1–2 days, plus one fix round if it's rejected.
