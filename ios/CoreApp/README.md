# core. — iOS app

A native SwiftUI rebuild of the "core." fitness-club prototype (dark UI,
orange accent), covering onboarding, home, booking, calendar/plan, trainers,
workout sessions, nutrition, diagnostics, vitamins, a label scanner, store,
an AI assistant, a QR membership pass and profile — all wired to working
local state (no backend required).

## Requirements

- Xcode 15.4+ (built against the iOS 17 SDK)
- iOS 17+ device or simulator
- A free or paid Apple Developer account for signing

## Open & run

1. Open `CoreApp.xcodeproj` in Xcode.
2. Select the **CoreApp** scheme and any simulator (or a connected device).
3. Select your team under the target's **Signing & Capabilities** tab (the
   project uses automatic signing) and change **Bundle Identifier** from the
   placeholder `com.coreclub.app` to something unique to you.
4. Press **Run** (⌘R).

## Deploying

1. Pick **Any iOS Device** as the run destination.
2. **Product ▸ Archive**.
3. In the Organizer, **Distribute App** → App Store Connect (TestFlight/App
   Store) or Ad Hoc/Enterprise, depending on your account.

No API keys, backend URLs, or extra configuration are required to build and
run — every screen operates on in-memory mock data defined in `AppState.swift`.

## What's actually functional

- **Workout timer** — live countdown with pause/resume and a lift checklist
  (Home → "Continue Push A" / Plan → tap a workout).
- **Booking** — zone occupancy with a real reserve action that updates the
  bar and remaining spots.
- **Nutrition** — macro rings, a water counter, and an add/remove meal flow
  that updates today's calories.
- **Vitamins** — tap any item to toggle taken/due.
- **Diagnostics** — Body/Blood/Vitamins tabs with a hand-drawn weight trend
  chart.
- **Scanner** — uses the real camera (`AVFoundation`) and on-device text
  recognition (`Vision`) to read a supplement label and flag a matching
  interaction note. Falls back to a simulated result in the simulator,
  where there's no camera.
- **QR pass** — a real, scannable QR code generated on-device with
  `CoreImage`, rotating every 30 seconds, plus a check-in action that logs a
  new visit.
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
  CoreAppApp.swift        entry point
  ContentView.swift        root tab bar (Home / Plan / Pass / Body / Me)
  Theme.swift               colors, fonts, shared modifiers
  Components.swift          reusable UI (rings, bars, cards, buttons)
  Models.swift               data types
  AppState.swift             single observable store + all app logic
  OnboardingView.swift
  HomeView.swift
  BookingView.swift
  PlanView.swift
  TrainersView.swift
  WorkoutSessionView.swift
  NutritionView.swift
  DiagnosticsView.swift
  VitaminsView.swift
  ScannerView.swift
  StoreView.swift
  AIAssistantView.swift
  QRPassView.swift
  ProfileView.swift
  Assets.xcassets/          app icon + accent color
  Info.plist
```

## Notes

- The bundle identifier, display name, and app icon are placeholders —
  update `Info.plist`'s `CFBundleDisplayName`, the target's
  `PRODUCT_BUNDLE_IDENTIFIER`, and `Assets.xcassets/AppIcon.appiconset` with
  your own branding before shipping.
- The app forces dark mode (`UIUserInterfaceStyle = Dark`) to match the
  source design; remove that key from `Info.plist` if you want to support
  light mode too.
