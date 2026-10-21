# core. — iOS app

A native SwiftUI build matching the Figma source exactly — nothing added,
nothing carried over from an earlier design pass. It covers precisely the
13 screens in that file: a splash screen, sign-in (Google / Apple / phone)
and OTP verification, a 4-step onboarding wizard (gender, goal,
contraindications, level), Home, the Workouts Library, Profile, Personal
Trainers, Supplements, and Food recipes.

## Requirements

- Xcode 26+ (built against the iOS 26 SDK, for real Liquid Glass — see Notes)
- iOS 26+ device or simulator
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
below) but **disabled by default** — the app goes splash → onboarding →
straight to Home. Flip `requiresSignIn` to `true` at the top of
`CoreAppApp.swift` to re-gate the app behind the sign-in screen.

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

Bottom tab bar: **Home** · a raised orange **Workouts** button in the
center · **Me**. That's the whole tab bar — there is no Calendar or
Diagnostics tab, because the source has no screens for them.

Home's icon grid (Book / Trainers / Food / Store / Scan / Core AI) matches
the source exactly, but only **Trainers**, **Food**, and **Store** open
anything — **Book**, **Scan**, and **Core AI** have no destination screen
in the Figma file, so they render as in the design but don't navigate.
Same story for Profile's **QR access pass** row and **Membership** card:
present exactly as designed, not wired to a screen that doesn't exist.

## What's actually functional

- **Sign in with Apple** — fully working, native, no extra account needed
  beyond the bundled entitlement (`CoreApp.entitlements`).
- **Sign in with Google** — fully working once you complete the Google
  Cloud setup above (`AuthService.swift`, using the real `GoogleSignIn` SDK).
- **Phone entry + OTP screen** — the UI (name/phone form, 4-digit code
  circles with auto-advance, resend cooldown) is fully interactive and any
  4-digit code completes sign-in. Actually *sending* an SMS code needs a
  backend such as Firebase Phone Auth or Twilio Verify.
- **Onboarding wizard** — gender, goal, contraindications (chips + free
  text), and experience level, all persisted to `AppState` for a future
  personalization pass to read.
- **Trainers** — search field UI, a two-up grid with a working
  favorite/heart toggle per card, and a detail sheet (bio, tags, stats,
  slot picker, book action) for each trainer.
- **Supplements** — a product grid with add-to-cart, and a running
  checkout bar; tapping a product opens a detail sheet with full
  ingredients/benefits/risks/interactions and its own add-to-cart.
- **Food recipes** — a browsable photo-card grid, matching the source's
  four recipes.
- **Profile** — Apple Health sync toggle (local switch only — see below)
  and a working Logout button (`AuthService.signOut()`).

## Connection to the core. gym platform

The app is connected to the core. platform — the dashboard the gym's front
desk and owner use (`web/` and `supabase/` in this repository). After a
member signs in with an email code, `CoreMemberService.swift` links the
account to their record at the gym and the app shows real data:

| Where | What comes from the platform |
|---|---|
| Sign-in → "Choose your gym" sheet | if the account isn't a client yet, the member picks a gym and becomes a client there |
| Profile → QR access pass | a rotating pass (`CORE1:…`, new code every 30 s, signed with this iPhone's secret) that the reception scanner accepts |
| Home → Book | the gym's class schedule with free spots, booking and cancellation |
| Home → wallet (Subscriptions) | the member's memberships, freezing, and buying a plan online (Stripe in the UAE, YooKassa in Russia) |
| Profile | real name, visit count, member-since date and current membership; **Delete account** |

Workouts, recipes, the store, trainers and Core AI keep using the app's own
tables (`supabase/*.sql` in this folder).

### Setup

1. **One Supabase project for both.** In `CoreApp/Info.plist` set
   `CoreSupabaseURL` and `CoreSupabaseAnonKey` to the platform's project
   (the dashboard's `NEXT_PUBLIC_SUPABASE_URL` and
   `NEXT_PUBLIC_SUPABASE_ANON_KEY`). If the app's own tables (trainers,
   products, workouts…) aren't in that project yet, run this folder's
   `supabase/schema.sql` and the `add_*.sql` files there — they don't clash
   with the platform's tables.
2. **Platform migrations.** The project must include the platform
   migrations up to `supabase/migrations/20261021000001_ios_app.sql`
   (sign-in by email, joining a gym from the app).
3. **`CorePlatformURL`** in `Info.plist` — the dashboard's address (used for
   online payment and account deletion), e.g.
   `https://streamlit-example-6xag.vercel.app`.
4. Build and run. Sign in with email → choose a gym (or ask the front desk
   to add your email to your client card — the app then finds you
   automatically) → Profile → QR access pass, and scan it at the front desk
   in the dashboard (Reception → scan).

Apple and Google sign-in in this app don't create a Supabase session, so
those members see the app without gym data; use email sign-in for the gym
features.

## Project layout

```
CoreApp.xcodeproj/
CoreApp/
  CoreAppApp.swift          entry point + splash/onboarding/sign-in/app routing
  AuthService.swift         Apple / Google / phone sign-in logic
  SplashView.swift          launch splash
  AuthWelcomeView.swift     sign-in screen (name/phone + Google/Apple)
  OTPVerificationView.swift phone code entry
  OnboardingView.swift      4-step wizard (gender/goal/contraindications/level)
  ContentView.swift         root tab bar (Home / Workouts / Me)
  Theme.swift               colors, font, Liquid Glass modifiers
  Components.swift          reusable UI (progress bar, buttons, photo placeholder)
  Models.swift              data types
  AppState.swift            single observable store + all app logic
  HomeView.swift            hero + occupancy + progress + icon grid
  WorkoutsView.swift        Workouts Library (filters + curated sections)
  TrainersView.swift        grid + trainer detail
  StoreView.swift           Supplements grid + cart + product detail
  FoodRecipesView.swift     recipe grid
  ProfileView.swift
  Assets.xcassets/          app icon, accent color, auth background
  Fonts/                    Doto-VariableFont.ttf
  Info.plist
  CoreApp.entitlements      Sign in with Apple capability
```

## Notes

- **Liquid Glass**: the deployment target is iOS 26.0 so the app can use the
  real system `glassEffect`/`GlassEffectContainer` API and the
  `.glassProminent` button style — not an `.ultraThinMaterial` approximation.
  It's used throughout: the tab bar, every floating icon button (search,
  favorite, add-to-cart), the sign-in/verification cards and OTP digit
  circles, and every primary CTA button (`PrimaryButton`, via
  `Theme.swift`'s `glassCard`/`glassCircleButton` helpers). This is a real
  compatibility trade-off — the app no longer runs on iOS 17–25 — so lower
  the deployment target and fall back to `.ultraThinMaterial` if you need
  to support older devices.
- **No stock photography**: the source design uses real photos (gym
  interiors, trainer portraits, dishes) that aren't available here, so
  `PhotoPlaceholder` (`Components.swift`) renders a themed gradient in
  their place. Swap in real `Image(...)` calls once you have licensed
  assets.
- The bundle identifier and display name are placeholders — update
  `Info.plist`'s `CFBundleDisplayName` and the target's
  `PRODUCT_BUNDLE_IDENTIFIER` with your own before shipping. The app icon
  and splash (`Assets.xcassets/AppIcon.appiconset`,
  `Assets.xcassets/CoreLogo.imageset`) are generated from the "core." logo.
- The sign-in screen's background (`Assets.xcassets/AuthBackground`) is a
  generated abstract dark gradient, not a licensed photo — swap it for your
  own gym photography before shipping.
- The app forces dark mode (`UIUserInterfaceStyle = Dark`) to match the
  source design; remove that key from `Info.plist` if you want to support
  light mode too.
- **Colors and corner radii** in `Theme.swift` are ported 1:1 from the
  design's CSS custom properties (`--bg`, `--surf`, `--surf2`, `--line`,
  `--ink`, `--muted`, `--accent`, `--good`, `--warn`, `--r`, `--r-s`), plus
  a secondary indigo/violet CTA accent used for onboarding, sign-in, and
  the membership card.
- **Font**: `Fonts/Doto-VariableFont.ttf`, registered via `UIAppFonts` in
  Info.plist, is the dot-matrix/LED font used everywhere the design calls
  for a digital-display look — occupancy, progress, prices
  (`Font.digitalTimer(_:)`). It ships as a single variable-weight file;
  `Font.digitalTimer(_:)` pins it to the PostScript name `Doto-Black` (its
  heaviest, most legible instance at small sizes) — swap that string for
  another named instance (Thin…ExtraBold) if you want a lighter feel. Doto
  is an open-source Google Font (SIL Open Font License) and is fine to ship.
- **Apple Health toggle** on Profile is a local switch — enabling real
  HealthKit sync means adding the HealthKit capability/entitlement in
  Signing & Capabilities and replacing the toggle's handler with
  `HKHealthStore` authorization calls.
