import SwiftUI

/// The Progress tab — confirmed as a real tab by the source's nav bar
/// component, but no dedicated Progress screen frame was in the Figma
/// file, so this surfaces the same real training-progress data as Home's
/// "Your Progress" card, plus calories burned and workout history so the
/// tab is actually useful on its own rather than duplicating Home.
struct ProgressTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var isShowingAllHistory = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Progress")
                    .font(.brand(32))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 12) {
                    EyebrowLabel(text: "Training progress")
                    Text("\(appState.trainingProgressPercent)%")
                        .font(.digitalTimer(48))
                        .foregroundStyle(.white)
                    ProgressBarView(value: Double(appState.trainingProgressPercent) / 100, color: .appAccentPurple, height: 10)
                    HStack {
                        Text("day \(appState.trainingDay)").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                        Spacer()
                        Text("\(appState.trainingMinutesToday) mins training").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                    }
                }
                .appCard(padding: 20)

                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: "Body Composition (InBody)")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        statTile(value: String(format: "%.1f%%", appState.bodyFatPercent), label: "Body Fat")
                        statTile(value: String(format: "%.1f%%", appState.totalBodyWaterPercent), label: "Total Body Water")
                        statTile(value: "\(appState.visceralFatIndex)", label: "Visceral Fat Index")
                        statTile(value: "\(appState.basalMetabolicRate)", label: "Basal Metabolic Rate")
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    EyebrowLabel(text: "Calories burned")
                    Text("\(appState.todayCalories)")
                        .font(.digitalTimer(48))
                        .foregroundStyle(.white)
                        + Text(" kcal today")
                        .font(.brand(16))
                        .foregroundStyle(Color.appTextSecondary)
                    Text("\(appState.totalCaloriesThisWeek) kcal this week")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appTextSecondary)
                }
                .appCard(padding: 20)

                VStack(alignment: .leading, spacing: 12) {
                    EyebrowLabel(text: "Club occupancy")
                    HStack(alignment: .bottom, spacing: 10) {
                        Text("\(appState.occupancyPercent)")
                            .font(.digitalTimer(38))
                            .foregroundStyle(.white)
                        Text("\(appState.occupancyInClub) of \(appState.occupancyCapacity) in the club")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.bottom, 6)
                    }
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(appState.occupancyBars.indices, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(i == 3 ? Color.appAccent : Color.appSurfaceElevated)
                                .frame(height: max(4, appState.occupancyBars[i] * 40))
                        }
                    }
                    .frame(height: 40, alignment: .bottom)
                }
                .appCard(padding: 20)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        EyebrowLabel(text: "Workout history")
                        Spacer()
                        Button("See all") { isShowingAllHistory = true }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                    VStack(spacing: 10) {
                        ForEach(appState.workoutHistory.prefix(3)) { entry in
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
        .sheet(isPresented: $isShowingAllHistory) {
            WorkoutHistoryView()
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

/// Opened via "See all" on the Progress tab's history section — every
/// logged past workout, not just the latest three.
private struct WorkoutHistoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(appState.workoutHistory) { entry in
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
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Workout history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
        }
    }
}

#Preview {
    ProgressTabView()
        .environmentObject(AppState())
}
