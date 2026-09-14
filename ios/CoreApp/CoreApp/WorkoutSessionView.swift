import SwiftUI

/// Matches "isTrain": the active workout session — elapsed timer, current
/// lift, a set-tracking table, a rest timer, live stats and a next-lift button.
struct WorkoutSessionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                topBar
                liftHeader
                setsTable
                restCard
                statsGrid
                PrimaryButton(title: "Next lift · \(appState.nextLiftName)") {
                    appState.advanceToNextLift()
                }
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { if appState.isWorkoutInProgress { appState.startTimer() } }
    }

    private var topBar: some View {
        HStack {
            Button("END") { dismiss() }
                .font(.system(size: 12, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(Color.appAccent).frame(width: 7, height: 7)
                Text(appState.workoutTimeString)
                    .font(.digitalTimer(20))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button(appState.isWorkoutInProgress ? "PAUSE" : "RESUME") {
                appState.toggleWorkout()
            }
            .font(.system(size: 12, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(Color.appAccent)
        }
    }

    private var liftHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            EyebrowLabel(text: "Lift \(appState.currentLiftIndex + 1) of \(appState.totalLifts) · Push A")
            Text(appState.currentLiftName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            Text(appState.currentLiftNote)
                .font(.system(size: 13))
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private var setsTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SET").frame(width: 40, alignment: .leading)
                Text("WEIGHT").frame(maxWidth: .infinity, alignment: .leading)
                Text("REPS").frame(maxWidth: .infinity, alignment: .leading)
                Text("DONE").frame(width: 64, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(Color.appTextSecondary)
            .padding(16)
            AppDivider()

            ForEach(Array(appState.sets.enumerated()), id: \.element.id) { index, set in
                HStack {
                    Text("\(index + 1)").font(.digitalTimer(16)).foregroundStyle(Color.appTextSecondary).frame(width: 40, alignment: .leading)
                    Text(String(format: "%.1f", set.weight)).font(.digitalTimer(18)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(set.reps)").font(.digitalTimer(18)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        appState.toggleSet(set)
                    } label: {
                        ZStack {
                            Circle().fill(set.isDone ? Color.appAccent : Color.clear)
                            Circle().stroke(set.isDone ? .clear : Color.appDivider, lineWidth: 1)
                            if set.isDone {
                                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            }
                        }
                        .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 64, alignment: .trailing)
                }
                .padding(16)
                AppDivider()
            }

            Button("+ Add set") { appState.addSet() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    private var restCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                EyebrowLabel(text: "Rest timer")
                Spacer()
                Text(AppState.mmss(appState.restSeconds))
                    .font(.digitalTimer(26))
                    .foregroundStyle(appState.restSeconds > 0 ? Color.appAccent : Color.appTextSecondary)
            }
            ProgressBarView(value: min(1, Double(appState.restSeconds) / 180), color: .appAccent, height: 8)
            HStack(spacing: 8) {
                restButton("90 s") { appState.startRest(90) }
                restButton("3 min") { appState.startRest(180) }
                restButton("Skip", muted: true) { appState.startRest(0) }
            }
        }
        .appCard(padding: 20)
    }

    private func restButton(_ title: String, muted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(muted ? Color.appTextSecondary : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .overlay(Capsule().stroke(Color.appDivider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var statsGrid: some View {
        HStack(spacing: 10) {
            statTile(value: "\(appState.completedVolume)", label: "Volume kg")
            statTile(value: "\(appState.doneSetsCount)", label: "Sets done")
            statTile(value: "\(appState.avgHeartRate)", label: "Avg bpm")
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
}

#Preview {
    NavigationStack { WorkoutSessionView() }
        .environmentObject(AppState())
}
