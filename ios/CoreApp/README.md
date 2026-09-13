# core. — iOS app

A native SwiftUI rebuild of the "core." fitness-club prototype (dark UI),
covering a splash screen, sign-in (Google / Apple / phone), home, booking,
calendar/plan, trainers, workout sessions, nutrition, diagnostics, vitamins,
a label scanner, store, an AI assistant, a QR membership pass, a progress
screen and profile — all wired to working local state (no backend required
except where noted below).

## Requirements

- Xcode 15.4+ (built against the iOS 17 SDK)
- iOS 17+ device or simulator
- A free or paid Apple Developer account for signing
- An internet connection the first time you open the project, so Xcode can
  resolve the GoogleSignIn Swift Package dependency

## Open & run

1. Open `CoreApp.xcodeproj` in Xcode — it will resolve the GoogleSignIn
   package automatically (Xcode shows "Resolving Package Graph").
2. Select the **CoreApp** scheme and any simulator (or a connected device).
3. Select your team under the target's **Signing & Capabilities** tab (the
   project uses automatic signing) and change **Bundle Identifier** from the
   placeholder `com.coreclub.app` to something unique to you.
4. Press **Run** (⌘R).

Sign-in with **Apple** works immediately (native `AuthenticationServices`,
no external account needed). Sign-in with **Google** needs a one-time setup
— see below — until then tapping the Google button will show a sign-in
error alert. Phone entry always works (see the note under AI/OTP below).

## Setting up Google Sign-In (one-time, in your own Google Cloud project)

Nobody can complete this step for you — it requires *your* Google account:

1. Go to the [Google Cloud Console](https://console.cloud.google.com/) →
   create (or pick) a project → **APIs & Services → Credentials**.
2. **Create Credentials → OAuth client ID → iOS**. Set the bundle ID to
   whatever you set `PRODUCT_BUNDLE_IDENTIFIER` to in Xcode.
3. Copy the generated **Client ID** (`XXXX.apps.googleusercontent.com`) and
   its **reversed form** (Google's console shows it, or reverse the
   dot-separated segments, e.g. `com.googleusercontent.apps.XXXX`).
4. In `CoreApp/Info.plist`, replace:
   - `GIDClientID` value with your client ID
   - the `CFBundleURLSchemes` placeholder under `CFBundleURLTypes` with your
     reversed client ID
5. Build and run — the Google button now completes a real sign-in.

## Deploying

1. Pick **Any iOS Device** as the run destination.
2. **Product ▸ Archive**.
3. In the Organizer, **Distribute App** → App Store Connect (TestFlight/App
   Store) or Ad Hoc/Enterprise, depending on your account.

## What's actually functional

- **Sign in with Apple** — fully working, native, no extra account needed
  beyond the bundled entitlement (`CoreApp.entitlements`).
- **Sign in with Google** — fully working once you complete the Google
  Cloud setup above (`AuthService.swift`, using the real `GoogleSignIn` SDK).
- **Phone entry + OTP screen** — the UI (name/phone form, 4-digit code
  boxes with auto-advance, resend cooldown) is fully interactive and any
  4-digit code completes sign-in. Actually *sending* an SMS code needs a
  backend such as Firebase Phone Auth or Twilio Verify — wire that into
  `AuthService.completePhoneSignIn`.
- **Workout timer** — live countdown with pause/resume and a lift checklist
  (Home → "Continue Push A" / Plan → tap a workout).
- **Booking** — zone occupancy with a real reserve action that updates the
  bar and remaining spots.
- **Nutrition** — macro rings, a water counter, and an add/remove meal flow
  that updates today's calories.
- **Vitamins** — tap any item to toggle taken/due.
- **Diagnostics** — Body/Blood/Vitamins tabs with a hand-drawn weight trend
  chart, reachable from Profile → "Diagnostics history".
- **Progress** — streak calendar, a volume-vs-goal ring, sets, and a weekly
  volume chart, all driven by `AppState`.
- **Scanner** — uses the real camera (`AVFoundation`) and on-device text
  recognition (`Vision`) to read a supplement label and flag a matching
  interaction note. Falls back to a simulated result in the simulator,
  where there's no camera.
- **QR pass** — a real, scannable QR code generated on-device with
  `CoreImage`, rotating every 30 seconds, plus a check-in action that logs a
  new visit. Reachable from Home's top-right circular icon.
- **Store** — add-to-cart with a running total and a subscribe toggle.
- **AI assistant** — a scripted local chat (keyword-matched replies) so the
  screen is fully interactive without wiring up a real LLM API key. Swap the
  logic in `AppState.scriptedReply(for:state:)` for a real API call if you
  want live answers.
- **Apple Health toggle** on Profile is a local switch — enabling real
  HealthKit sync means adding the HealthKit capability/entitlement in
  Signing & Capabilities and replacing the toggle's handler with
  `HKHealthStore` authorization calls.

## Project layout

```
CoreApp.xcodeproj/
CoreApp/
  CoreAppApp.swift          entry point + splash/sign-in/app routing
  AuthService.swift         Apple / Google / phone sign-in logic
  SplashView.swift          launch splash
  AuthWelcomeView.swift     sign-in screen (name/phone + Google/Apple)
  OTPVerificationView.swift phone code entry
  ContentView.swift         root tab bar (Home / Plan / + / Progress / Me)
  Theme.swift               colors, fonts, shared modifiers
  Components.swift          reusable UI (bars, cards, buttons)
  Models.swift              data types
  AppState.swift            single observable store + all app logic
  HomeView.swift
  BookingView.swift
  PlanView.swift
  TrainersView.swift
  WorkoutSessionView.swift
  NutritionView.swift
  DiagnosticsView.swift
  VitaminsView.swift
  TrainingProgressView.swift
  ScannerView.swift
  StoreView.swift
  AIAssistantView.swift
  QRPassView.swift
  ProfileView.swift
  Assets.xcassets/          app icon, accent color, auth background
  Fonts/                    Francy-Regular.ttf, DotGothic16-Regular.ttf
  Info.plist
  CoreApp.entitlements      Sign in with Apple capability
```

## Notes

- The bundle identifier and display name are placeholders — update
  `Info.plist`'s `CFBundleDisplayName` and the target's
  `PRODUCT_BUNDLE_IDENTIFIER` with your own before shipping. The app icon
  and splash (`Assets.xcassets/AppIcon.appiconset`,
  `Assets.xcassets/CoreLogo.imageset`) are generated from the actual "core."
  logo file supplied with the design export, composited onto the app's
  `--bg` color (`#0A0A0B`) with its own background keyed out to transparent.
- The sign-in screen's background (`Assets.xcassets/AuthBackground`) is a
  generated abstract dark gradient, not a licensed photo — swap it for your
  own gym photography before shipping.
- The app forces dark mode (`UIUserInterfaceStyle = Dark`) to match the
  source design; remove that key from `Info.plist` if you want to support
  light mode too.
- **Colors and corner radii** in `Theme.swift` are ported 1:1 from the
  design's CSS custom properties (`--bg`, `--surf`, `--surf2`, `--line`,
  `--ink`, `--muted`, `--accent`, `--good`, `--warn`, `--r`, `--r-s`) rather
  than approximated, so they match the source exactly.
- **Fonts**: bundled in `CoreApp/Fonts/` and registered via `UIAppFonts` in
  Info.plist. `Francy-Regular.ttf` is the display font used for the splash
  wordmark and every big stat number (`Font.brand(_:)` in `Theme.swift`);
  `DotGothic16-Regular.ttf` is the pixel/LED font used for the workout timer
  and the QR pass member code (`Font.digitalTimer(_:)`). Make sure you have
  the right to embed and redistribute Francy in a shipped app before
  submitting to the App Store — DotGothic16 is an open-source Google Font
  (SIL Open Font License) and is fine to ship.
