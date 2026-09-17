import SwiftUI

/// Central design tokens for the app — ported 1:1 from the source design's
/// CSS custom properties (:root, :root[data-core-theme="dark"] in
/// "core App.dc.html"): --bg, --surf, --surf2, --line, --ink, --muted,
/// --accent, --good, --warn, --r, --r-s.
extension Color {
    static let appBackground = Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0B / 255)       // --bg
    static let appSurface = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x17 / 255)          // --surf
    static let appSurfaceElevated = Color(red: 0x1D / 255, green: 0x1D / 255, blue: 0x22 / 255)  // --surf2
    static let appAccent = Color(red: 0xFF / 255, green: 0x5A / 255, blue: 0x1F / 255)           // --accent
    static let appAccentDim = Color.appAccent.opacity(0.14)                                       // --soft
    static let appTextPrimary = Color(red: 0xF6 / 255, green: 0xF6 / 255, blue: 0xF5 / 255)      // --ink
    static let appTextSecondary = Color(red: 0x8A / 255, green: 0x8A / 255, blue: 0x93 / 255)    // --muted
    static let appSuccess = Color(red: 0x4A / 255, green: 0xDE / 255, blue: 0x80 / 255)          // --good
    static let appWarning = Color(red: 0xFA / 255, green: 0xCC / 255, blue: 0x15 / 255)          // --warn
    static let appDivider = Color(red: 0x27 / 255, green: 0x27 / 255, blue: 0x30 / 255)          // --line

    /// Secondary "liquid glass" CTA accent — the indigo/violet used for the
    /// onboarding wizard, sign-in/verification buttons, the membership card
    /// and the profile's Logout button in the latest Figma pass.
    static let appAccentPurple = Color(red: 0x5B / 255, green: 0x2C / 255, blue: 0xF0 / 255)
}

enum AppMetrics {
    static let cardCorner: CGFloat = 24   // --r
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
}

/// A small uppercase, letter-spaced label used above sections ("UPCOMING", "CLUB OCCUPANCY", ...).
struct EyebrowLabel: View {
    let text: String
    var color: Color = .appTextSecondary

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(color)
    }
}
