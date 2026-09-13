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

/// Big rounded numeric display used for readiness, weight, macros, etc.
struct BigNumber: View {
    let value: String
    var size: CGFloat = 40
    var color: Color = .appTextPrimary

    var body: some View {
        Text(value)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .monospacedDigit()
    }
}
