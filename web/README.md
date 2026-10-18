# core. — web app

A web/PWA port of the `ios/CoreApp` native app, built so members can use core. without installing anything from the App Store — open the URL, optionally "Add to Home Screen", done.

It shares the **same Supabase backend** as the iOS app (trainers, products, workout library, bookings, cart, member stats, etc. all live in one place — a booking made on iOS shows up here and vice versa). It does **not** share the iOS app's local-only UserDefaults data (profile edits, onboarding answers) — those are per-device on each platform.

## Stack

- Vite + React + TypeScript
- `react-router-dom` for navigation (one route per screen)
- `@supabase/supabase-js` talking to the same project as the iOS app
- `vite-plugin-pwa` for the installable/offline-shell behavior
- Hand-rolled CSS (`src/styles/global.css`) using the same design tokens as `Theme.swift` — no UI framework

## Running locally

```bash
npm install
npm run dev       # http://localhost:5173, hot reload
npm run build     # type-checks (tsc -b) then builds to dist/
npm run preview   # serves the production build locally
```

## Deploying

`npm run build` produces a static `dist/` folder — deploy it to any static host (Vercel, Netlify, Cloudflare Pages, GitHub Pages, S3+CloudFront, etc.). No server runtime is needed; all data access goes straight to Supabase from the browser. Make sure the host serves over **HTTPS** — a PWA's service worker and "Add to Home Screen" both require it (`localhost` is exempted for dev).

## What's different from the iOS app

A few iOS features have no real web equivalent — rather than silently drop them, each shows an honest in-app explanation instead of a fake/broken version:

- **Apple Health sync** (`/health`) — browsers have no comparable health-data store to read from.
- **Core AI** (`/core-ai`) — runs on Apple Intelligence (on-device) on iOS; there's no on-device model a browser tab can call, and no server-side AI backend is wired up here.
- **Camera barcode scanning** (`/scan`) — falls back to a text search over the product catalog instead.
- **Sign in with Apple / Google** — Apple sign-in needs a native app; Google sign-in needs OAuth credentials not set up for this project. **Email sign-in (OTP) works fully** — it's genuine Supabase Auth, identical on both platforms.
- **Home Screen widgets** — no web equivalent; the in-app Progress/Achievements and Health screens cover the same data.

## i18n

English/Russian strings are pulled from the iOS app's `Localizable.xcstrings` (`src/i18n/generatedDict.ts`, regenerated from that file — see the comment at its top) plus a hand-written set of web-only strings in `src/i18n/index.ts`. The language toggle lives in Profile and on the sign-in screen, same as iOS, and swaps the whole UI to Geologica for Russian the same way `Font.uiFontFamilyOverride` does natively.
