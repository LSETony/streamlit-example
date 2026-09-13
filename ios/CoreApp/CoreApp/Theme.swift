import SwiftUI

/// Central design tokens for the app. Colors approximate the "core." dark,
/// orange-accented gym-club design used throughout every screen.
extension Color {
    static let appBackground = Color(red: 0.043, green: 0.043, blue: 0.047)
    static let appSurface = Color(red: 0.094, green: 0.094, blue: 0.102)
    static let appSurfaceElevated = Color(red: 0.135, green: 0.135, blue: 0.145)
    static let appAccent = Color(red: 1.0, green: 0.341, blue: 0.129)
    static let appAccentDim = Color(red: 0.30, green: 0.14, blue: 0.07)
    static let appTextPrimary = Color.white
    static let appTextSecondary = Color(white: 0.62)
    static let appTextTertiary = Color(white: 0.42)
    static let appSuccess = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let appWarning = Color(red: 0.95, green: 0.62, blue: 0.07)
    static let appDivider = Color(white: 0.16)

    /// Primary brand/interactive color used for buttons, the in-progress
    /// banner and the tab bar's "+" action — introduced with the
    /// sign-in flow and Home/Progress redesign.
    static let appPurple = Color(red: 0.373, green: 0.290, blue: 0.965)
    static let appPurpleDim = Color(red: 0.373, green: 0.290, blue: 0.965).opacity(0.16)

    /// Warm reddish glow used behind the "Club occupancy" and "Your streak" cards.
    static let appGlowStart = Color(red: 0.28, green: 0.08, blue: 0.04)
    static let appGlowEnd = Color(red: 0.11, green: 0.05, blue: 0.05)
}

enum AppMetrics {
    static let cardCorner: CGFloat = 20
    static let smallCorner: CGFloat = 14
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

    /// Warm reddish "glow" card treatment used by Club Occupancy and Your Streak.
    func glowCard(padding: CGFloat = 18, corner: CGFloat = AppMetrics.cardCorner) -> some View {
        self
            .padding(padding)
            .background(
                LinearGradient(
                    colors: [.appGlowStart, .appGlowEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

/// Digital/7-segment-style monospaced font used for the workout timer.
extension Font {
    static func digitalTimer(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
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
