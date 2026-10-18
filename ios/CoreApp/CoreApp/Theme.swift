import SwiftUI

/// Central design tokens for the app — ported 1:1 from the source design's
/// CSS custom properties (:root, :root[data-core-theme="dark"] in
/// "core App.dc.html"): --bg, --surf, --surf2, --line, --ink, --muted,
/// --accent, --good, --warn, --r, --r-s.
extension Color {
    static let appBackground = Color(red: 0x1E / 255, green: 0x1E / 255, blue: 0x1E / 255)       // --bg
    static let appSurface = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x17 / 255)          // --surf
    static let appSurfaceElevated = Color(red: 0x1D / 255, green: 0x1D / 255, blue: 0x22 / 255)  // --surf2
    static let appAccent = Color(red: 0xF9 / 255, green: 0x2C / 255, blue: 0x00 / 255)           // --accent
    static let appAccentDim = Color.appAccent.opacity(0.14)                                       // --soft
    static let appTextPrimary = Color(red: 0xF6 / 255, green: 0xF6 / 255, blue: 0xF5 / 255)      // --ink
    static let appTextSecondary = Color(red: 0x8A / 255, green: 0x8A / 255, blue: 0x93 / 255)    // --muted
    static let appSuccess = Color(red: 0x4A / 255, green: 0xDE / 255, blue: 0x80 / 255)          // --good
    static let appWarning = Color(red: 0xFA / 255, green: 0xCC / 255, blue: 0x15 / 255)          // --warn
    static let appDivider = Color(red: 0x27 / 255, green: 0x27 / 255, blue: 0x30 / 255)          // --line

    /// Secondary "liquid glass" CTA accent — the indigo/violet used for the
    /// onboarding wizard, sign-in/verification buttons, the membership card
    /// and the profile's Logout button in the latest Figma pass.
    static let appAccentPurple = Color(red: 0x59 / 255, green: 0x00 / 255, blue: 0xFF / 255)

    /// The translucent warm-gray fill (rgba(60,56,56,0.2) in the source) on
    /// the onboarding wizard's option rows and contraindication chips —
    /// close to but distinct from appSurface/appSurfaceElevated, so kept as
    /// its own token rather than reusing a cooler gray that doesn't match.
    static let appOptionRowFill = Color(red: 0x3C / 255, green: 0x38 / 255, blue: 0x38 / 255).opacity(0.2)
}

enum AppMetrics {
    static let cardCorner: CGFloat = 30   // --r
    static let smallCorner: CGFloat = 16  // --r-s
    static let screenPadding: CGFloat = 20
}

extension View {
    /// Wraps a view in the app's standard dark card treatment.
    func appCard(padding: CGFloat = 16, corner: CGFloat = AppMetrics.cardCorner) -> some View {
        self
            .padding(padding)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    /// Standard horizontal screen padding used by every screen's content.
    func screenPadding() -> some View {
        self.padding(.horizontal, AppMetrics.screenPadding)
    }

    /// The app's real Liquid Glass card treatment (iOS 26 `glassEffect`) —
    /// used wherever the design puts a panel over a photo: auth cards, the
    /// Home hero's occupancy card, onboarding chrome. Deployment target is
    /// iOS 26+, so this is the genuine system material, not an approximation.
    func glassCard(padding: CGFloat = 16, corner: CGFloat = AppMetrics.cardCorner) -> some View {
        self
            .padding(padding)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    /// A round Liquid Glass icon button (search, bag, favorite ...): regular
    /// glass, interactive so it compresses/highlights on press like a native
    /// control.
    func glassCircleButton() -> some View {
        self.glassEffect(.regular.interactive(), in: Circle())
    }
}

/// "Doto" (a dot-matrix/LED look, used at its Black weight) for anything
/// meant to read like a digital display — occupancy, progress, prices.
extension Font {
    static func digitalTimer(_ size: CGFloat) -> Font {
        .custom("Doto-Black", size: size)
    }

    /// "Francy" — the brand display face used for each screen's main
    /// headline (page titles, the Home club name, names on detail cards).
    /// Francy has no Cyrillic glyphs of its own, so when the member's
    /// language is Russian, AppState swaps `brandFontOverride` to
    /// "Geologica-Medium" (which does) instead — every existing
    /// `.font(.brand(_:))` call site picks this up automatically, no
    /// per-view changes needed.
    static var brandFontOverride: String?

    static func brand(_ size: CGFloat) -> Font {
        .custom(brandFontOverride ?? "Francy-Regular", size: size)
    }

    /// Drop-in replacement for `.system(size:weight:)` used by every
    /// ordinary label/body/button string across the app (not just brand
    /// headlines) — hundreds of call sites. When AppState sets
    /// `uiFontFamilyOverride` (Russian — see its didSet), this swaps the
    /// system font for Geologica's Medium (500) weight everywhere at
    /// once, regardless of the `weight` the call site asked for — one
    /// consistent mid-weight across the whole app, by request, rather
    /// than mapping each system weight to its own Geologica weight.
    /// `nil` (the default, every other language) falls straight back to
    /// the real system font at its original weight, unchanged.
    static var uiFontFamilyOverride: String?

    static func uiText(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        guard let family = uiFontFamilyOverride else {
            return .system(size: size, weight: weight)
        }
        return .custom("\(family)-Medium", size: size)
    }
}

/// A small uppercase, letter-spaced label used above sections ("Upcoming", "Club Occupancy", ...).
struct EyebrowLabel: View {
    let text: String
    var color: Color = .appTextSecondary

    var body: some View {
        Text(Self.localizedUppercased(text))
            .font(.uiText(size: 12, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(color)
    }

    /// Runs `text` through the String Catalog first (so a translated
    /// Russian label gets uppercased, not the English source) and only
    /// then uppercases — `Text(text.uppercased())` would uppercase the
    /// English key before lookup, which never matches any catalog entry.
    /// Looked up against `AppLanguage.current` (the member's in-app
    /// choice) rather than the default `Locale.current` — `String(localized:)`
    /// doesn't see SwiftUI's `.environment(\.locale, ...)` override, so
    /// without this it would follow the device's system language instead
    /// of the language picked in Profile/sign-in.
    static func localizedUppercased(_ text: String) -> String {
        String(localized: String.LocalizationValue(text), locale: AppLanguage.current.locale).uppercased()
    }
}
