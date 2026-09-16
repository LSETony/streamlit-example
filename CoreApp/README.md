# core. — SwiftUI app

A native SwiftUI recreation of the "core." fitness-club app design from Figma
(file `Si72DJLpEzyusUqSZJzgbC`). Dark theme, purple/orange accents, built for iOS.

## Screens

| Figma frame | Screen | Source file |
|---|---|---|
| `iPhone 16 & 17 Pro Max - 1..3` | Splash ("core.") | `Onboarding/SplashView.swift` |
| `- 14` (step 1/4) | Gender | `Onboarding/GenderSelectionView.swift` |
| `- 4` (step 2/4) | Goal | `Onboarding/GoalSelectionView.swift` |
| `- 13` (step 3/4) | Health / contradictions | `Onboarding/HealthQuestionsView.swift` |
| `- 5` (step 4/4) | Fitness level | `Onboarding/LevelSelectionView.swift` |
| `- 6` | Home (Club Occupancy, Your Progress, quick actions) | `Main/HomeView.swift` |
| `- 7` | Progress detail (streak, status) | `Main/ProgressDetailView.swift` |
| `- 9` | Workout plans (Home → Book) | `Main/WorkoutPlansView.swift` |
| `- 11` | Personal Trainers (Home → Trainers) | `Main/PersonalTrainersView.swift` |
| `- 12` | Supplements (Home → Store) | `Main/SupplementsView.swift` |
| `- 15` | Food recipes (Home → Food) | `Main/FoodRecipesView.swift` |
| `- 10` | Profile / membership card | `Main/ProfileView.swift` |
| — | Scan, Core AI | `Main/PlaceholderScreens.swift` |

"Scan" and "Core AI" are two of the six Home quick-action tiles but have no dedicated
frame in the Figma file, so they're stubbed with the same visual language pending real
designs.

## Building

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the `.xcodeproj`
doesn't need to be hand-authored or committed:

```bash
brew install xcodegen   # once
cd CoreApp
xcodegen generate
open CoreApp.xcodeproj
```

Requires Xcode 15+ / iOS 16+ (SwiftUI only, no third-party dependencies).

## Known fidelity gaps

- **Fonts**: the design specifies the custom faces "Francy" (body/headings) and "Doto"
  (dot-matrix stat numbers). Neither ships with iOS; `DesignSystem/Theme.swift` falls
  back to rounded/monospaced system fonts. Drop the real `.ttf`/`.otf` files into the
  Xcode project, register them under `Info.plist → UIAppFonts`, and update
  `Theme.Typeface` to restore exact typography.
- **Icons & photography**: vector icons are approximated with SF Symbols and the gym
  hero photo is a gradient placeholder, since the original exported assets are only
  available as short-lived Figma URLs. Re-export from Figma (`get_design_context` /
  asset download) and drop them into `Assets.xcassets` to match pixel-for-pixel.
- Colors, radii, and layout come directly from the Figma node data
  (`#1E1E1E` / `#5900FF` / `#F92C00` / `#948C8C`, 45pt pill radius, 30pt card radius).
