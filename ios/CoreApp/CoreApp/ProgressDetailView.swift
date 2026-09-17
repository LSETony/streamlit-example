import SwiftUI

/// Opened by tapping the "Your Progress" card on Home. Shows the current
/// streak plus totals for sets/time/calories and a session-by-session
/// workout history.
struct ProgressDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Your Progress")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Image("IconTrending").customIcon(size: 16)
                                .foregroundStyle(Color.appAccent)
                        }
                        Text("\(appState.trainingProgressPercent)%")
                            .font(.digitalTimer(34))
                            .foregroundStyle(.white)
                        ProgressBarView(value: Double(appState.trainingProgressPercent) / 100, color: .appAccentPurple, height: 8)
                        Text("day \(appState.trainingDay)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .appCard(padding: 20)

                    HStack(spacing: 10) {
                        statTile(value: "\(appState.trainingSetsToday)", label: "Sets today")
                        statTile(value: "\(appState.trainingMinutesToday)", label: "Mins today")
                        statTile(value: "\(appState.trainingCaloriesToday)", label: "Kcal today")
                    }

                    HStack(spacing: 10) {
                        statTile(value: "\(appState.totalSetsThisWeek)", label: "Sets · week")
                        statTile(value: "\(appState.totalMinutesThisWeek)", label: "Mins · week")
                        statTile(value: "\(appState.totalCaloriesThisWeek)", label: "Kcal · week")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowLabel(text: "Workout history")
                        VStack(spacing: 10) {
                            ForEach(appState.workoutHistory) { entry in
                                historyRow(entry)
                            }
                        }
                    }
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.digitalTimer(20)).foregroundStyle(.white)
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.4).foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }

    private func historyRow(_ entry: WorkoutHistoryEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(entry.date)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.sets) sets · \(entry.minutes) min")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
                Text("\(entry.calories) kcal")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appAccent)
            }
        }
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

#Preview {
    ProgressDetailView()
        .environmentObject(AppState())
}
