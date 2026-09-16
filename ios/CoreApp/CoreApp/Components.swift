import SwiftUI

/// Horizontal capacity/occupancy bar used in Booking and Nutrition.
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

/// Small colored uppercase status badge, e.g. "BOOKED", "TAKEN", "DUE".
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(color)
    }
}

/// Compact stat tile used in the Home quick-stats row and Profile.
struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.brand(24))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

/// Full-width call-to-action button used across screens ("Capture",
/// "Confirm check-in", "Subscribe" ...) — real Liquid Glass via the
/// system's `.glassProminent` button style, tinted per call site.
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

/// Row header pairing an eyebrow label on the left with a trailing accent
/// action/link label, e.g. "UPCOMING" ... "CALENDAR".
struct SectionHeaderRow: View {
    let title: String
    var trailing: String? = nil
    var trailingAction: () -> Void = {}

    var body: some View {
        HStack {
            EyebrowLabel(text: title)
            Spacer()
            if let trailing {
                Button(action: trailingAction) {
                    Text(trailing.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Rounded avatar with initials, used by Trainers.
struct InitialsAvatar: View {
    let initials: String
    var color: Color = .appAccent
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.18))
            Text(initials)
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

/// Divider matching the app's subtle line color.
struct AppDivider: View {
    var body: some View {
        Rectangle().fill(Color.appDivider).frame(height: 1)
    }
}

/// A themed gradient stand-in for photography (gym floor, trainer portrait,
/// a dish) — there's no licensed photo asset to embed, so this keeps the
/// exact card shapes/proportions from the design while staying honest that
/// it isn't a real photo. Swap in `Image(...)` here once real shots exist.
struct PhotoPlaceholder: View {
    enum Style { case gym, trainer, food, event }
    var style: Style = .gym
    var icon: String? = nil

    private var colors: [Color] {
        switch style {
        case .gym: return [Color(red: 0.11, green: 0.11, blue: 0.13), Color(red: 0.03, green: 0.03, blue: 0.04)]
        case .trainer: return [Color(red: 0.15, green: 0.13, blue: 0.17), Color(red: 0.04, green: 0.035, blue: 0.05)]
        case .food: return [Color(red: 0.24, green: 0.14, blue: 0.06), Color(red: 0.06, green: 0.035, blue: 0.02)]
        case .event: return [Color(red: 0.14, green: 0.10, blue: 0.20), Color(red: 0.04, green: 0.03, blue: 0.07)]
        }
    }

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

/// Small circular favorite/heart toggle used on trainer and product cards.
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
