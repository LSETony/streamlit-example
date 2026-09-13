import SwiftUI

/// The "Progress" tab — streak calendar, volume ring, sets and a weekly
/// training-volume chart.
struct TrainingProgressView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: MainTab
    @State private var range = "This month"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    streakCard
                    HStack(spacing: 10) {
                        volumeCard
                        VStack(spacing: 10) {
                            statCard(icon: "clock", title: "Sets", value: "\(appState.totalSets)")
                            statCard(icon: "flag.fill", title: "Exercises", value: "\(appState.exerciseMinutesThisMonth) min")
                        }
                    }
                    weeklyChartCard
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        HStack {
            Text("Progress")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Menu {
                Button("This month") { range = "This month" }
                Button("This week") { range = "This week" }
                Button("All time") { range = "All time" }
            } label: {
                HStack(spacing: 6) {
                    Text(range.lowercased())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.appSurface)
                .clipShape(Capsule())
            }
        }
    }

    private var streakCard: some View {
        Button {
            selectedTab = .plan
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Your streak")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(appState.streakDateLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appTextSecondary)
                }
                HStack(spacing: 0) {
                    ForEach(appState.streakDays) { day in
                        VStack(spacing: 8) {
                            Text(day.letter)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.appTextSecondary)
                            ZStack {
                                Circle().fill(circleColor(for: day.state))
                                Text("\(day.number)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(day.state == .upcoming ? Color.appTextSecondary : .white)
                            }
                            .frame(width: 32, height: 32)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                HStack {
                    Spacer()
                    Text("view calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
            }
            .glowCard()
        }
        .buttonStyle(.plain)
    }

    private func circleColor(for state: StreakDayState) -> Color {
        switch state {
        case .completed: return .white
        case .today: return .appAccent
        case .upcoming: return Color.white.opacity(0.12)
        }
    }

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill").font(.system(size: 12)).foregroundStyle(Color.appAccent)
                Text("Volume").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            }
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: Double(appState.volumePercentOfGoal) / 100)
                    .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(appState.volumePercentOfGoal)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("% of goal")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .frame(width: 84, height: 84)
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    private func statCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            EyebrowLabel(text: "This week's volume")
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(appState.weeklyVolumeBars, id: \.day) { bar in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(bar.isToday ? Color.appAccent : Color.white.opacity(0.18))
                            .frame(height: max(10, bar.value * 90))
                        Text(bar.day)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120, alignment: .bottom)
        }
        .appCard()
    }
}

#Preview {
    TrainingProgressView(selectedTab: .constant(.progress))
        .environmentObject(AppState())
}
