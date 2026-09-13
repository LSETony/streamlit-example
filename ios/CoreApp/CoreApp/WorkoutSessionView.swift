import SwiftUI

struct WorkoutSessionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var completedCount: Int { appState.lifts.filter(\.isDone).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    EyebrowLabel(text: "Push A · heavy upper body")
                    Text(appState.workoutTimeString)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("\(completedCount) of \(appState.lifts.count) lifts complete")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

                PrimaryButton(title: appState.isWorkoutInProgress ? "Pause" : "Resume") {
                    appState.toggleWorkout()
                }

                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: "Lifts")
                    ForEach(appState.lifts) { lift in
                        Button {
                            appState.toggleLift(lift)
                        } label: {
                            HStack {
                                Image(systemName: lift.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(lift.isDone ? Color.appSuccess : Color.appTextTertiary)
                                    .font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lift.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .strikethrough(lift.isDone)
                                    Text("\(lift.sets) sets · \(lift.reps) reps")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
            }
        }
        .onAppear {
            if appState.isWorkoutInProgress { appState.startTimer() }
        }
    }
}

#Preview {
    NavigationStack { WorkoutSessionView() }
        .environmentObject(AppState())
}
