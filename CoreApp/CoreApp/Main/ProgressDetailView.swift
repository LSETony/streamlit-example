import SwiftUI

/// Figma frame 52:203 "iPhone 16 & 17 Pro Max - 7".
struct ProgressDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Progress")
                        .font(Theme.Typeface.display(32, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 6) {
                        Text("this month").font(Theme.Typeface.display(16)).foregroundStyle(.white)
                        Image(systemName: "chevron.down").font(.system(size: 12)).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(
                        LinearGradient(colors: [Color.black.opacity(0.2), Theme.orange.opacity(0.15)], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }

                streakCard
                statusRow
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 60)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Your streak").font(Theme.Typeface.display(24, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text("Wed 3 Oct").font(Theme.Typeface.display(16)).foregroundStyle(.white)
            }

            WeekdayStrip(highlighted: [0: .white, 2: Theme.orange])

            HStack {
                Spacer()
                Text("view calendar")
                    .font(Theme.Typeface.display(16))
                    .foregroundStyle(Theme.orange)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private var statusRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURRENT STATUS").font(Theme.Typeface.display(16)).foregroundStyle(Theme.muted)

            HStack(spacing: 14) {
                VStack(spacing: 8) {
                    RingStat(value: 54, caption: "54", label: "% of goal")
                        .frame(width: 128, height: 113)
                }
                .padding(16)
                .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))

                VStack(spacing: 12) {
                    statTile(icon: "flame", value: "802", label: "Sets")
                    statTile(icon: "figure.strengthtraining.traditional", value: "54 min", label: "Excercises")
                }
            }

            Text("CURRENT STATUS").font(Theme.Typeface.display(16)).foregroundStyle(Theme.muted).padding(.top, 8)

            VStack(alignment: .leading, spacing: 14) {
                WeeklyBarChart(values: [0.5, 0.7, 0.9, 0.6, 0.4, 0.8, 0.65], labels: [], highlightIndex: 2)
                WeekdayStrip(highlighted: [:])
            }
            .padding(20)
            .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        }
    }

    private func statTile(icon: String, value: String, label: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(Theme.Typeface.stat(28)).foregroundStyle(.white)
                Text(label).font(Theme.Typeface.display(16)).foregroundStyle(.white)
            }
            Spacer()
            Image(systemName: icon).foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

#Preview {
    NavigationStack { ProgressDetailView() }
}
