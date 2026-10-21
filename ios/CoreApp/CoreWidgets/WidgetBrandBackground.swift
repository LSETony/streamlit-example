import SwiftUI

/// Shared `containerBackground(for: .widget)` fill for every core. Home
/// Screen widget — a dark surface-to-background gradient with two soft
/// brand-color glows (the accent/purple duo used for every ring, gradient
/// and highlight elsewhere in the app), instead of the flat single color
/// the widgets used before. Keeps every widget reading as one family while
/// giving each a bit of depth/life on the Home Screen and in StandBy.
struct WidgetBrandBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.appSurfaceElevated, Color.appBackground],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(colors: [Color.appAccent.opacity(0.16), .clear], center: .topTrailing, startRadius: 0, endRadius: 160)
            RadialGradient(colors: [Color.appAccentPurple.opacity(0.14), .clear], center: .bottomLeading, startRadius: 0, endRadius: 160)
        }
    }
}
