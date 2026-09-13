import SwiftUI

/// Circular readiness ring, e.g. the "72 READY" indicator on Home.
struct RingProgressView: View {
    let progress: Double // 0...1
    var size: CGFloat = 84
    var lineWidth: CGFloat = 8
    var color: Color = .appAccent
    var centerValue: String
    var centerLabel: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(centerValue)
                    .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(centerLabel.uppercased())
                    .font(.system(size: size * 0.11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.appTextSecondary)
            }
        }
        .frame(width: size, height: size)
    }
}

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
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

/// Square icon tile used in the "Club services" grid on Home.
struct ServiceTile: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.appAccent)
                Spacer(minLength: 0)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.appTextSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 100)
            .padding(14)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Filled, full-width call-to-action button used across screens ("Capture",
/// "Confirm check-in", "Subscribe" ...).
struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isEnabled ? Color.appAccent : Color.appAccent.opacity(0.4))
                .clipShape(Capsule())
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
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
                        .foregroundStyle(.appAccent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Simple bar chart used for club occupancy-by-hour on Home.
struct BarChartView: View {
    let bars: [(hour: Int, value: Double)]
    var highlightHour: Int? = nil

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(bars, id: \.hour) { bar in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(bar.hour == highlightHour ? Color.appAccent : Color.white.opacity(0.18))
                        .frame(height: max(6, bar.value * 60))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 60, alignment: .bottom)
            HStack {
                ForEach(bars, id: \.hour) { bar in
                    Text(String(format: "%02d", bar.hour))
                        .font(.system(size: 11))
                        .foregroundStyle(.appTextTertiary)
                        .frame(maxWidth: .infinity)
                }
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
