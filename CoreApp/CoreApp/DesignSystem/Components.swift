import SwiftUI

// MARK: - Primary pill button ("Continue" / "Logout" — Figma "Component 3")

struct PrimaryButton: View {
    let title: String
    var color: Color = Theme.purple
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typeface.display(20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .background(color, in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Onboarding step header ("Component 28/31": back button + progress track + "x/4")

struct OnboardingHeader: View {
    let title: String
    let subtitle: String
    let step: Int
    let totalSteps: Int
    var onBack: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.Typeface.display(32, weight: .bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(Theme.Typeface.display(16))
                .foregroundStyle(Theme.muted)

            HStack(spacing: 12) {
                Button {
                    onBack?()
                } label: {
                    ZStack {
                        Circle().fill(Theme.cardFill)
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.white)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(onBack == nil)
                .opacity(onBack == nil ? 0 : 1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.placeholder.opacity(0.3))
                        Capsule()
                            .fill(Theme.orange)
                            .frame(width: geo.size.width * CGFloat(step) / CGFloat(totalSteps))
                    }
                }
                .frame(height: 8)

                Text("\(step)/\(totalSteps)")
                    .font(Theme.Typeface.display(16))
                    .foregroundStyle(Theme.muted)
            }
            .frame(height: 36)
        }
    }
}

// MARK: - Selectable option row (goal selection list)

struct OptionRow: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .frame(width: 20)
                Text(title)
                    .font(Theme.Typeface.display(16, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                ZStack {
                    Circle().fill(isSelected ? Theme.orange : Color.clear)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
            .frame(height: 79)
            .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gender selection bar (163:373)

struct SelectableBar: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(Theme.Typeface.display(24, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                ZStack {
                    Circle().stroke(Color.white, lineWidth: 1)
                    if isSelected {
                        Circle().fill(Theme.orange).padding(4)
                    }
                }
                .frame(width: 32, height: 32)
            }
            .padding(.horizontal, 24)
            .frame(height: 72)
            .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Level selection tile (51:704, 2x2 grid)

struct LevelTile: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(Theme.Typeface.display(16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(Theme.Typeface.display(14))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 193, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(isSelected ? Theme.orange : Color.white, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search bar row (Trainers / Supplements / Food recipes)

struct SearchBarRow: View {
    @Binding var text: String
    var onFilterTap: (() -> Void)? = nil
    var onGridTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white)
                TextField("search", text: $text)
                    .font(Theme.Typeface.display(16))
                    .foregroundStyle(.white)
                    .tint(.white)
            }
            .padding(.horizontal, 20)
            .frame(height: 50)
            .background(Theme.panelFill, in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))

            Button(action: { onFilterTap?() }) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Theme.panelFill, in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: { onGridTap?() }) {
                Image(systemName: "square.grid.2x2")
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Theme.panelFill, in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Screen header ("Personal Trainers" / "Supplements" / "Food recipes")

struct ScreenTitle: View {
    let title: String
    var body: some View {
        Text(title)
            .font(Theme.Typeface.display(32, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Home quick-action grid tile

/// Plain visual content (no internal `Button`) so it can be used as a `NavigationLink` label
/// without nesting interactive controls.
struct QuickActionTile: View {
    let icon: String
    let title: String
    var highlighted: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
            Text(title)
                .font(Theme.Typeface.display(16, weight: .medium))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 105)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(highlighted ? Theme.orange : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(highlighted ? Theme.orange : Color.white, lineWidth: 1)
        )
    }
}

// MARK: - Weekly bar chart (Club occupancy / Progress volume)

struct WeeklyBarChart: View {
    /// 0...1 normalized bar heights. `labels` is optional per-bar and may be shorter
    /// than (or empty relative to) `values` — bars without a label just omit the caption.
    let values: [CGFloat]
    let labels: [String]
    let highlightIndex: Int?

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            ForEach(values.indices, id: \.self) { i in
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(i == highlightIndex ? Theme.orange : Theme.placeholder)
                        .frame(height: 80 * max(values[i], 0.08))
                    if i < labels.count {
                        Text(labels[i])
                            .font(Theme.Typeface.display(12))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .frame(height: 110, alignment: .bottom)
    }
}

// MARK: - Weekday strip (S M T W T F S) with a couple of highlighted days

struct WeekdayStrip: View {
    let highlighted: [Int: Color]

    private let days = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(days.indices, id: \.self) { i in
                ZStack {
                    Circle().fill(highlighted[i] ?? Theme.placeholder.opacity(0.15))
                    Text(days[i])
                        .font(Theme.Typeface.display(14, weight: .medium))
                        .foregroundStyle(highlighted[i] == Theme.orange ? .white : (highlighted[i] != nil ? .black : .white))
                }
                .frame(width: 48, height: 47)
            }
        }
    }
}

// MARK: - Circular ring stat ("% of goal")

struct RingStat: View {
    let value: Double
    let caption: String
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .rotation(.degrees(135))
                .stroke(Theme.placeholder.opacity(0.25), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            Circle()
                .trim(from: 0, to: 0.75 * value / 100)
                .rotation(.degrees(135))
                .stroke(Theme.orange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
            VStack(spacing: 2) {
                Text(caption)
                    .font(Theme.Typeface.stat(28))
                    .foregroundStyle(.white)
                Text(label)
                    .font(Theme.Typeface.display(11))
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}

// MARK: - Generic translucent panel container

struct Panel<Content: View>: View {
    var fill: Color = Theme.panelFill
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}
