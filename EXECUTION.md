# EXECUTION PLAN

> **Workflow:** sessions split into **PLANNING** (draft the spec, this file) and
> **EXECUTION** (build it). This file is **rewritten in full** every planning
> cycle and describes only the *current* target.

**Status: WAITING ON THE USER. The code is done; the first Play upload needs the user's keystore and Play Console setup.**

## Done (committed to `main`)

**`348c014` feat(app): add the Sảnh hall behind the Long Ký seal**
- The seal in Home's top-right corner opens the Sảnh (`/sanh`): a lacquer panel with a gold frame, the brand lockup, a Chào cờ card, and a directory (Niên biểu, Bản đồ lãnh thổ, Về Long Ký).
- **Chào cờ is daily:** an always-on Home pill reads "CHÀO CỜ HÔM NAY". On 30/4 and 2/9 it names the day. The button on the 2/9/1945 event is gone.
- **Về Long Ký** (`/sanh/gioi-thieu`) shows the approved copy. Cited works are in bold gold italic, and it includes "do người Việt, vì người Việt".
- **The "Mời Long Ký một chén trà" tip** is a $0.99 consumable, `long_ky_tea`, using `in_app_purchase`.
  - The row only appears once the store product loads, so it stays hidden until Play is set up.
  - A successful purchase shows a thank-you sheet.

**`c6261eb` build(android): rename the package to app.longky and sign releases with an upload key**
- `applicationId` and `namespace` are now `app.longky`, and `MainActivity` moved to match. The iOS bundle id is aligned.
- Release builds read `android/key.properties` (gitignored). Without it they fall back to the debug key.

**Verified:**
- analyze is clean.
- 117 app tests pass, including 10 new Sảnh tests.
- The debug APK builds with the new package.
- Web smoke test at 375×812: Home seal and pill, the Sảnh in VI and EN, and Về Long Ký.
- The tea row is correctly absent on web.

## Remaining: the user, in order
1. **Create the upload keystore.** Keep it and its passwords safe; losing it blocks updates until Google resets the key.
   ```bash
   keytool -genkey -v -keystore ~/long-ky-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Then write `apps/mobile/android/key.properties`:
   ```
   storePassword=…
   keyPassword=…
   keyAlias=upload
   storeFile=/Users/binhnguyen/long-ky-upload.jks
   ```
   Back up both files outside the repo.
2. **Tell Claude it exists.** Claude then runs:
   - `flutter build appbundle --release` in `apps/mobile`.
   - A `jarsigner` check that the bundle carries the upload certificate, not "Android Debug".

   Claude never reads the passwords.
3. **Play Console:**
   - Create the app "Long Ký" (default language Vietnamese, App, Free). Keep **Play App Signing** on.
   - Set up the **payments profile** (bank and tax details).
4. **Internal testing:**
   - Upload `build/app/outputs/bundle/release/app-release.aab`.
   - Add yourself as a tester and accept the opt-in link on your phone.
5. **In-app product:** create `long_ky_tea`. It is a managed product, $0.99, with name "Một chén trà". The description is: "Mời Long Ký một chén trà: tiếp sức để Long Ký viết tiếp sử Việt, miễn phí và không quảng cáo." **Activate** it.
6. **License testing:** add your account under Settings → License testing.
7. **Test on the phone:**
   - Install from internal testing.
   - Open Sảnh → "Mời Long Ký một chén trà" and buy with the test card.
   - The thank-you sheet should appear. Buy again to confirm the purchase is consumable.
8. **Before any wider release,** fill in Play's app content forms: privacy policy URL, data safety (no personal data collected), content rating, and target audience. Claude can draft the privacy policy and the data-safety answers.

**Every later upload must raise the `+N` build number** in `apps/mobile/pubspec.yaml`, which is currently `1.0.0+1`.

## Next cycles (queued, in order)
1. **The chronicle, 1977 → 2025.**
   - Complete Era 32 (1977–1986).
   - Add a new **Đổi Mới** period with Era 35 (1986–1995, including Gạc Ma 1988), Era 36 (1996–2007, WTO), Era 37 (2008–2019) and Era 38 (2020–2025).
   - Peacetime growth counts as history in full. Check every growth figure against Gov and GSO sources.
2. **Câu đố (quizzes)**, as a new Sảnh row.
3. **A soft tip ask** after finishing an era: shown once, dismissible, never on first launch.
4. **iOS build and App Store in-app purchase** for the tip (Guideline 3.1.1). This needs Xcode and an Apple Developer account.

## Still awaiting the user's yes/no (from earlier cycles)
- **Era 30/31 photo-hero recaption:** real archival photos there are captioned "Minh họa · phong cách sơn mài". Recaption them "Ảnh tư liệu · phục chế màu". This is a separate `fix(content)` commit plus a publish.
