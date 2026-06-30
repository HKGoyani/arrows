# App Store Submission Guide — Arrows – Escape Puzzle v1.0.0

This document has everything needed to submit v1.0.0 to App Store Connect. Last reviewed against the codebase on 2026-06-30.

---

## ⚠️ Critical — must fix before submission

These are **blocking** issues. The app as built today will not function correctly for real users if shipped as-is.

| Item | Current state | Required action |
|---|---|---|
| **AdMob App ID** | Test ID `ca-app-pub-3940256099942544~1458002511` in `ios/Runner/Info.plist` (`GADApplicationIdentifier`) | Replace with your real AdMob App ID from the AdMob console |
| **Ad Unit IDs** | All 4 ad formats (rewarded, interstitial, banner, app open) use Google's shared test IDs in `lib/ad_service.dart` | Create real ad units in AdMob console for `com.shayona.arrows` and swap in the real IDs (one set per platform — iOS/Android already branch via `Platform.isIOS`) |
| **App Tracking Transparency** | `NSUserTrackingUsageDescription` is **missing** from `ios/Runner/Info.plist` | Add this key with a user-facing string (e.g. "This identifier will be used to deliver personalized ads to you."). Without it, iOS will not show the ATT prompt and AdMob may fail to request tracking permission, or Apple may reject the build for using IDFA without disclosure |
| **In-App Purchase product** | Only exists in the local `Configuration.storekit` test file | Create the real `remove_ads` non-consumable product in **App Store Connect → Monetization → In-App Purchases**, set price tier, and submit it for review alongside the binary |
| **App screenshots** | None created yet | Required for all supported device sizes before submission (see Screenshots section below) |

---

## 1. App Information

| Field | Value |
|---|---|
| **App Name** | Arrows – Escape Puzzle |
| **Subtitle** (30 char max) | Arrow puzzle, escape & relax |
| **Bundle ID** | `com.shayona.arrows` |
| **SKU** | `arrows-escape-puzzle-ios` (or any internal identifier) |
| **Primary Language** | English (U.S.) |
| **Apple ID (App Store Connect)** | 6785821757 |
| **Version** | 1.0.0 |
| **Build number** | 1 |
| **Bundle Display Name** | Arrows – Escape Puzzle |
| **Category (Primary)** | Games → Puzzle |
| **Category (Secondary)** | Games → Casual *(optional)* |
| **Content Rights** | Confirm "Does not use third-party content" unless otherwise applicable |
| **Age Rating** | 4+ (no objectionable content; see Age Rating section below) |

---

## 2. Device & Platform Support

| Setting | Value | Where it's set |
|---|---|---|
| Supported devices | **iPhone only** — iPad, Mac (Designed for iPad), and Apple Vision Pro are explicitly excluded | `TARGETED_DEVICE_FAMILY = "1"` in `ios/Runner.xcodeproj/project.pbxproj` (all 3 build configs) |
| Minimum iOS version | **15.0** | `IPHONEOS_DEPLOYMENT_TARGET = 15.0` (required by `firebase_analytics`) |
| Orientation | Portrait only | `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` in `lib/main.dart` |

---

## 3. App Icon

| Detail | Value |
|---|---|
| Design | Black arrows (one up, two left) with a red diagonal "ESCAPE" banner |
| Master asset | `assets/icon/app_icon_master.png` (1254×1254, RGB, no alpha) |
| App Store marketing icon | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` (1024×1024) |
| All other sizes | Generated and present in the same `.appiconset` folder (20pt–83.5pt × 1x/2x/3x for iPhone) |

No further action needed — icon is fully wired in Xcode and ready for archive/upload.

---

## 4. Screenshots — ⚠️ NOT YET CREATED

App Store Connect requires screenshots for at least one device size per device family submitted. Since this is iPhone-only, you need:

| Required size | Display size used for | Status |
|---|---|---|
| 6.9" (iPhone 16 Pro Max / 15 Pro Max class) | Required — largest current iPhone | ❌ Not created |
| 6.5" (iPhone 11 Pro Max / XS Max class) | Optional if 6.9" provided and scales | ❌ Not created |

**Recommended shots (5–10 total):**
1. Home screen with Play button and streak
2. Mid-game board (Hard or Super Hard tier, visually dense)
3. Win celebration screen
4. Daily Challenge calendar screen
5. Collection screen (badges/records)
6. Dark mode variant of one of the above
7. A shaped-level board (heart, star, or peach) for visual variety

Use the iOS Simulator's screenshot tool (`xcrun simctl io <device> screenshot`) on the 6.9" simulator class, or capture on a real device. These can be captured directly from the running app — no design work needed beyond picking good in-game moments.

---

## 5. App Store Listing Copy

### Promotional Text (170 char, editable without re-review)
> Free, relaxing arrow-puzzle escape game. New daily challenges, streaks, and brain-teasing boards that get trickier the further you go!

### Description
```
Arrows – Escape Puzzle is a calm, satisfying logic puzzle: tap an arrow,
watch it slide free if the path is clear, or turn red if it's blocked.
Clear the whole board to win — no timers, no pressure, just you and
the puzzle.

HOW TO PLAY
• Tap any arrow to fire it off the board
• A clear path means it flies free
• A blocked path costs you a life — you have 3
• Clear every arrow to win the level

FEATURES
• Hundreds of procedurally generated levels that scale in difficulty
• Four difficulty tiers: Normal, Hard, Super Hard, and Nightmare
• Daily Challenges with their own streak and trophy calendar
• Track your longest streak, best win streak, and most wins in a day
• Unlock Level Legend, Perfect Play, and Unstoppable badges
• Specially shaped boards (circle, heart, star, and more) at milestone levels
• Free hints, with extra hints available any time
• Full dark mode support
• Available in 10 languages

Arrows – Escape Puzzle is free to play, with optional ads and a
one-time Remove Ads purchase for an uninterrupted experience.
```

### Keywords (100 char max, comma-separated, no spaces after commas)
```
arrow,puzzle,escape,maze,logic,brain,relax,daily challenge,streak,offline
```

### Support URL
```
https://hkgoyani.github.io/arrows-legal/support.html
```

### Marketing URL (optional)
```
https://hkgoyani.github.io/arrows-legal/
```

### Privacy Policy URL (required)
```
https://hkgoyani.github.io/arrows-legal/privacy-policy.html
```

---

## 6. Privacy & Data Collection (App Store "Privacy Nutrition Label")

Based on the actual implementation — fill in App Store Connect's Privacy questionnaire as follows.

| Data Type | Collected? | Linked to identity? | Used for tracking? | Notes |
|---|---|---|---|---|
| **Identifiers** (Device ID / IDFA) | Yes | No | Yes (advertising) | Via Google AdMob, only if user grants ATT |
| **Usage Data** (Product Interaction) | Yes | No | No | Via Firebase Analytics — `level_start`, `level_win`, `level_lose`, `level_restart`, `hint_used`, `daily_challenge_complete`, `streak_extended`, `ad_shown`, `purchase_remove_ads` |
| **Purchases** | Yes | No | No | Purchase confirmation only (product ID), no payment details — processed entirely by Apple |
| **Diagnostics** (Crash Data, Performance) | No | — | — | Not currently integrated (no Crashlytics) |
| **Contact Info, Health, Financial, Location, Browsing History, Photos, Contacts** | No | — | — | App collects none of these |

**Tracking:** Answer **Yes** to "Does this app track users?" because AdMob may use IDFA for ad personalization if ATT consent is granted. The App Tracking Transparency prompt must be implemented (see Critical section above) before this can be answered honestly.

**Full policy text:** https://hkgoyani.github.io/arrows-legal/privacy-policy.html

---

## 7. Pricing

| Setting | Value |
|---|---|
| **App price** | Free |
| **Availability** | All territories (or restrict as desired) |
| **Pre-order** | Not used |

---

## 8. In-App Purchases

| Field | Value |
|---|---|
| **Reference Name** | Remove Ads |
| **Product ID** | `remove_ads` |
| **Type** | Non-Consumable |
| **Price** | $3.99 USD (Apple will auto-localize to other currencies/territories) |
| **Display Name** (shown to users) | Remove Ads |
| **Description** | Remove all fullscreen ads between levels. Life refill and Hint ads will still be available. |
| **Review screenshot** | Capture the in-app "Remove Ads" popup (Settings → Remove Ads) showing the price and description |

**Setup steps in App Store Connect:**
1. Go to **App → Monetization → In-App Purchases → +**
2. Choose **Non-Consumable**
3. Enter Reference Name "Remove Ads", Product ID `remove_ads` (must exactly match `IapService.removeAdsId` in `lib/iap_service.dart`)
4. Set price tier equivalent to $3.99 USD
5. Add the display name/description above, attach the review screenshot
6. Submit for review — this can be submitted alongside the app binary in the same review

**Local testing reference:** A StoreKit Configuration file already exists at `ios/Runner/Configuration.storekit` with matching product ID for Simulator testing — this is dev-only and is not part of the shipped app.

---

## 9. Ads Disclosure (App Review notes)

The app shows ads via **Google AdMob** in 4 formats:

| Format | Trigger |
|---|---|
| Rewarded | Hint (after 5 free hints), Add More Lives (lose screen) |
| Interstitial | Every 3rd level win, level restart, daily challenge complete |
| Banner | Bottom of Home, Challenge, Collection, Settings tabs |
| App Open | App resume from background / cold start (never during active gameplay) |

All ads can be permanently disabled (except rewarded, which is opt-in) via the **Remove Ads** IAP.

---

## 10. Age Rating Questionnaire

Recommended answers for Apple's Age Rating questionnaire — the game has no objectionable content of any kind:

| Category | Answer |
|---|---|
| Cartoon/Fantasy/Realistic Violence | None |
| Sexual Content/Nudity | None |
| Profanity/Crude Humor | None |
| Alcohol/Tobacco/Drugs | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Gambling (Simulated) | None |
| Unrestricted Web Access | No |
| **Loot Boxes / random in-app purchases** | No — Remove Ads is a fixed-price, non-randomized purchase |

Expected result: **4+**

---

## 11. Export Compliance (Encryption)

| Question | Answer | Why |
|---|---|---|
| Does the app use encryption? | Yes (uses standard HTTPS/TLS only) | All network calls (Firebase, AdMob, StoreKit) use standard OS-provided HTTPS |
| Does it qualify for exemption? | Yes — standard encryption exemption | The app does not implement custom/proprietary encryption |

**Action needed:** Add `ITSAppUsesNonExemptEncryption = false` to `ios/Runner/Info.plist` to skip the manual export-compliance question on every build upload. Currently this key is **not set**, so Xcode/App Store Connect will prompt for it on every upload.

---

## 12. App Review Notes (paste into the "Notes" field)

```
Arrows – Escape Puzzle is a single-player offline puzzle game. No login
or account is required to play.

- All gameplay progress is stored locally on-device (no server backend).
- Ads are served via Google AdMob (test ad units must be swapped for
  production IDs before this build is approved for release — see
  internal notes).
- One in-app purchase: "Remove Ads" ($3.99, non-consumable, product ID
  remove_ads) disables banner/interstitial/app-open ads. Rewarded ads
  (opt-in, for hints/extra lives) remain available even after purchase
  by design — this is disclosed in the purchase description shown to
  users in Settings.
- Firebase Analytics is used for anonymous, aggregated usage events only
  (no PII collected).
- No account creation, no chat, no user-generated content, no web view
  with unrestricted browsing.

Test path: tap Play on the Home screen to start Level 1 (tutorial),
or tap an in-progress level number to continue.
```

---

## 13. Build & Archive Checklist

Run through this immediately before archiving in Xcode:

- [ ] Swap test AdMob App ID → production App ID in `Info.plist`
- [ ] Swap all 4 test ad unit IDs → production IDs in `lib/ad_service.dart`
- [ ] Add `NSUserTrackingUsageDescription` to `Info.plist`
- [ ] Add `ITSAppUsesNonExemptEncryption = false` to `Info.plist`
- [ ] Create real `remove_ads` IAP product in App Store Connect
- [ ] Capture and upload App Store screenshots (6.9" minimum)
- [ ] Confirm `pubspec.yaml` version is `1.0.0+1` (already set)
- [ ] Run `flutter build ipa` (or archive via Xcode with `ios/Runner.xcworkspace`)
- [ ] Test the production build on a real device — confirm ATT prompt appears, ads load, IAP purchase flow works end-to-end with a Sandbox tester account
- [ ] Upload via Xcode Organizer or Transporter
- [ ] Submit for review with the notes from Section 12

---

## 14. Reference Links

| Resource | URL |
|---|---|
| Privacy Policy | https://hkgoyani.github.io/arrows-legal/privacy-policy.html |
| Terms & Conditions | https://hkgoyani.github.io/arrows-legal/terms-and-conditions.html |
| Support page | https://hkgoyani.github.io/arrows-legal/support.html |
| Support email | akashmangukiya10@gmail.com |
| Apple ID (App Store Connect numeric ID) | 6785821757 |
| Bundle ID | com.shayona.arrows |
| Firebase project | fitflow-759df |
