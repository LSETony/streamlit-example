import SwiftUI

/// Horizontal progress bar used by the Home "Your Progress" card.
struct ProgressBarView: View {
    let value: Double // 0...1
    var color: Color = .appAccent
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(color)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

/// Full-width call-to-action button used across screens ("Continue",
/// "Logout", "Add to cart" ...) — real Liquid Glass via the system's
/// `.glassProminent` button style, tinted per call site.
struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var color: Color = .appAccent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.glassProminent)
        .tint(color)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Divider matching the app's subtle line color.
struct AppDivider: View {
    var body: some View {
        Rectangle().fill(Color.appDivider).frame(height: 1)
    }
}

/// A themed gradient stand-in for a dish photo — there's no licensed food
/// photography to embed yet, so this keeps Food recipes' exact card shapes
/// while staying honest that it isn't a real photo. Swap in `Image(...)`
/// here once real shots exist.
struct PhotoPlaceholder: View {
    var icon: String? = nil

    private let colors = [Color(red: 0.24, green: 0.14, blue: 0.06), Color(red: 0.06, green: 0.035, blue: 0.02)]

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.white.opacity(0.22))
            }
        }
    }
}

/// Small circular favorite/heart toggle used on trainer cards.
struct FavoriteButton: View {
    @Binding var isFavorite: Bool

    var body: some View {
        Button { isFavorite.toggle() } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.appAccent : .white)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .glassCircleButton()
    }
}
