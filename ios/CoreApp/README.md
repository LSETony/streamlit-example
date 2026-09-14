# core. — iOS app

A native SwiftUI rebuild of the "core." fitness-club prototype, ported 1:1
from the design source ("core App.dc.html" + "Onboarding.dc.html") — same
copy, same colors, same layout. Covers a splash screen, sign-in (Google /
Apple / phone), home, booking, calendar, trainers + trainer detail, a
training plan, workouts (personal / group classes / solo), an active
workout session, nutrition, diagnostics (body / blood / vitamins), a label
scanner, a supplements store with product detail, an AI assistant, a QR
membership pass and profile — all wired to working local state (no backend
required except where noted below).

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

Sign-in is built (Apple works immediately; Google needs the one-time setup
below) but **disabled by default** — the app opens straight to Home after
the splash. Flip `requiresSignIn` to `true` at the top of `CoreAppApp.swift`
to re-gate the app behind the sign-in screen.

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
5. Build and run (with `requiresSignIn = true`) — the Google button now
   completes a real sign-in.

## Deploying

1. Pick **Any iOS Device** as the run destination.
2. **Product ▸ Archive**.
3. In the Organizer, **Distribute App** → App Store Connect (TestFlight/App
   Store) or Ad Hoc/Enterprise, depending on your account.

## Navigation

Bottom tab bar: **Home** · **Calendar** · a raised orange **Workouts**
button in the center · **Diagnostics** · **Me**. Workouts has three tabs
(Personal / Group / Solo); its header list icon and a couple of its rows
open **Plan** (week compliance, exercise library, history) — Plan isn't a
tab itself, it's reached from there or from ending an active workout.

## What's actually functional

- **Sign in with Apple** — fully working, native, no extra account needed
  beyond the bundled entitlement (`CoreApp.entitlements`).
- **Sign in with Google** — fully working once you complete the Google
  Cloud setup above (`AuthService.swift`, using the real `GoogleSignIn` SDK).
- **Phone entry + OTP screen** — the UI (name/phone form, 4-digit code
  boxes with auto-advance, resend cooldown) is fully interactive and any
  4-digit code completes sign-in. Actually *sending* an SMS code needs a
  backend such as Firebase Phone Auth or Twilio Verify.
- **Workout session** — a real elapsed-time timer, a set-tracking table
  (weight/reps/done), a rest timer, live volume/set/heart-rate stats, and a
  next-lift action, matching the source's "Train" screen exactly.
- **Booking** — date/zone/time/duration pickers with a live forecast-load
  summary and a real reserve action.
- **Nutrition** — a 2 600 kcal target, macro bars, a water counter, and an
  add/remove meal flow, all computed from `AppState.meals`.
- **Vitamins** — tap any protocol item to toggle taken/due; a supply card
  links to Store and Scanner.
- **Diagnostics** — Body (weight trend, body composition) / Blood (flagged
  vs. in-range labs) / Vitamins tabs, reachable from the tab bar or from
  Profile → "Diagnostics history".
- **Store** — a subscription bundle, a 6-product grid with full product
  detail pages (ingredients, benefits, risks, interactions), and a cart with
  checkout.
- **Scanner** — uses the real camera (`AVFoundation`) and on-device text
  recognition (`Vision`) to read a supplement label and flag a matching
  interaction note. Falls back to the source's own demo scenario (a
  flagged 50 mg zinc label) in the simulator, where there's no camera.
- **QR pass** — a real, scannable QR code generated on-device with
  `CoreImage`, rotating every 30 seconds, plus a check-in/out action that
  logs a new visit. Reachable from Profile → "QR access pass".
- **AI assistant** — a scripted local chat (keyword-matched replies, same
  copy as the source) so the screen is fully interactive without wiring up
  a real LLM API key. Swap the logic in `AppState.sendChatMessage` for a
  real API call if you want live answers.
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
  ContentView.swift         root tab bar (Home / Calendar / Workouts / Diagnostics / Me)
  Theme.swift               colors, fonts, shared modifiers
  Components.swift          reusable UI (bars, cards, buttons)
  Models.swift              data types
  AppState.swift            single observable store + all app logic
  HomeView.swift
  BookingView.swift
  CalendarView.swift
  TrainersView.swift        list + trainer detail
  PlanView.swift
  WorkoutsView.swift        Personal / Group / Solo
  WorkoutSessionView.swift  active workout
  NutritionView.swift
  DiagnosticsView.swift     Body / Blood / Vitamins tabs
  VitaminsView.swift        vitamins protocol list (used inside Diagnostics)
  ScannerView.swift
  StoreView.swift           grid + cart + product detail
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
  `DotGothic16-Regular.ttf` is the pixel/LED font used everywhere the source
  used `font-family: DotGothic16` — timers, dates, prices, codes
  (`Font.digitalTimer(_:)`). Make sure you have the right to embed and
  redistribute Francy in a shipped app before submitting to the App Store —
  DotGothic16 is an open-source Google Font (SIL Open Font License) and is
  fine to ship.
