import SwiftUI

/// Lets a member build their own workout: pick a zone to focus on, then
/// check off which exercises from that zone to include. "Start Workout"
/// assembles a plain WorkoutCard from the selection and hands it back to
/// WorkoutsView via `onCreate`, which opens it through the exact same
/// WorkoutDetailView sheet every catalog card uses — no changes needed
/// there, a custom workout is just a WorkoutCard that didn't come from
/// Supabase.
///
/// The exercise pool is static/curated client-side content (like
/// GymSafetyView's rules or EventsView's events) rather than a new
/// Supabase table — there's no muscle-group tagging on the existing
/// catalog exercises to build this from, and a fixed, well-chosen list
/// per zone is enough for a member to put together a real session.
struct CustomWorkoutBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (WorkoutCard) -> Void

    @State private var selectedZone: WorkoutZone = .chest
    @State private var selectedExerciseIDs: Set<UUID> = []

    private var exercisesForZone: [Exercise] { WorkoutZone.exercisePool[selectedZone] ?? [] }
    private var selectedExercises: [Exercise] { exercisesForZone.filter { selectedExerciseIDs.contains($0.id) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "Build Your Own", color: .appAccentPurple)
                        Text("Custom Workout")
                            .font(.brand(28))
                            .foregroundStyle(.white)
                        Text("Pick a zone to focus on, then choose which exercises to include.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("FOCUS ZONE").font(.system(size: 11, weight: .semibold)).tracking(0.5).foregroundStyle(Color.appTextSecondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(WorkoutZone.allCases) { zone in
                                    zoneChip(zone)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("EXERCISES").font(.system(size: 11, weight: .semibold)).tracking(0.5).foregroundStyle(Color.appTextSecondary)
                            Spacer()
                            Text("\(selectedExerciseIDs.count) selected")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.appAccentPurple)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(exercisesForZone.enumerated()), id: \.element.id) { index, exercise in
                                if index > 0 { AppDivider() }
                                exerciseRow(exercise)
                            }
                        }
                        .glassCard(padding: 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
                                .stroke(.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 110)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(
                    title: selectedExerciseIDs.isEmpty ? "Select exercises to start" : "Start Workout · \(selectedExerciseIDs.count) exercises",
                    isEnabled: !selectedExerciseIDs.isEmpty, color: .appAccentPurple
                ) {
                    let card = WorkoutCard(
                        imageName: selectedZone.imageName, title: "My \(selectedZone.name) Workout",
                        level: "Custom", duration: "\(selectedExercises.count * 5) min", category: "Strength",
                        exercises: selectedExercises
                    )
                    dismiss()
                    onCreate(card)
                }
                .screenPadding()
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
            .onChange(of: selectedZone) { _, _ in selectedExerciseIDs.removeAll() }
        }
    }

    private func zoneChip(_ zone: WorkoutZone) -> some View {
        let isOn = selectedZone == zone
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedZone = zone }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: zone.icon).font(.system(size: 12, weight: .semibold))
                Text(zone.name).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isOn ? .white : Color.appTextSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .glassEffect(isOn ? .regular.tint(.appAccentPurple).interactive() : .regular.interactive(), in: Capsule())
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        let isSelected = selectedExerciseIDs.contains(exercise.id)
        return Button {
            if isSelected { selectedExerciseIDs.remove(exercise.id) } else { selectedExerciseIDs.insert(exercise.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: exercise.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.appAccentPurple : Color.appTextSecondary)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                    Text("\(exercise.sets) sets · \(exercise.reps)").font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(isSelected ? Color.appAccentPurple : Color.appTextSecondary.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A body-focus category for the custom workout builder — distinct from
/// GymZone (physical areas of the club, like "Strength Floor"), this is
/// about which muscle group/training style the picked exercises target.
enum WorkoutZone: String, CaseIterable, Identifiable {
    case chest, back, legs, shoulders, arms, core, cardio

    var id: String { rawValue }

    var name: String {
        switch self {
        case .chest: "Chest"
        case .back: "Back"
        case .legs: "Legs"
        case .shoulders: "Shoulders"
        case .arms: "Arms"
        case .core: "Core"
        case .cardio: "Cardio"
        }
    }

    var icon: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.rower"
        case .legs: "figure.strengthtraining.functional"
        case .shoulders: "figure.boxing"
        case .arms: "dumbbell.fill"
        case .core: "figure.core.training"
        case .cardio: "figure.run"
        }
    }

    /// Reused for the assembled WorkoutCard's cover — one of the bundled
    /// workout images already in Assets.xcassets, close enough in spirit
    /// to each zone that there's no need for 7 new dedicated photos.
    var imageName: String {
        switch self {
        case .chest: "WorkoutChestTriceps"
        case .back: "WorkoutGymCandid1"
        case .legs: "WorkoutBodyWeight"
        case .shoulders: "WorkoutGymCandid1"
        case .arms: "WorkoutChestTriceps"
        case .core: "WorkoutBodyWeight"
        case .cardio: "WorkoutPrentalFlow"
        }
    }

    /// Built once — Exercise's `id` is a fresh UUID per instance, so this
    /// pool has to be a stored constant rather than a computed property,
    /// or the builder's Set<UUID> selection would lose track of which
    /// rows are checked on every view update.
    static let exercisePool: [WorkoutZone: [Exercise]] = [
        .chest: [
            Exercise(name: "Barbell Bench Press", icon: "figure.strengthtraining.traditional", sets: 4, reps: "8"),
            Exercise(name: "Incline Dumbbell Press", icon: "figure.strengthtraining.traditional", sets: 3, reps: "10"),
            Exercise(name: "Push-ups", icon: "figure.strengthtraining.traditional", sets: 3, reps: "15"),
            Exercise(name: "Cable Flyes", icon: "figure.strengthtraining.traditional", sets: 3, reps: "12"),
            Exercise(name: "Dips", icon: "figure.strengthtraining.traditional", sets: 3, reps: "10"),
            Exercise(name: "Chest Press Machine", icon: "figure.strengthtraining.traditional", sets: 3, reps: "12"),
        ],
        .back: [
            Exercise(name: "Deadlift", icon: "figure.strengthtraining.functional", sets: 4, reps: "6"),
            Exercise(name: "Pull-ups", icon: "figure.strengthtraining.traditional", sets: 3, reps: "8"),
            Exercise(name: "Lat Pulldown", icon: "figure.rower", sets: 3, reps: "12"),
            Exercise(name: "Seated Cable Row", icon: "figure.rower", sets: 3, reps: "12"),
            Exercise(name: "Bent-over Row", icon: "figure.strengthtraining.traditional", sets: 3, reps: "10"),
            Exercise(name: "Face Pulls", icon: "figure.rower", sets: 3, reps: "15"),
        ],
        .legs: [
            Exercise(name: "Barbell Squats", icon: "figure.strengthtraining.functional", sets: 4, reps: "8"),
            Exercise(name: "Romanian Deadlift", icon: "figure.strengthtraining.functional", sets: 3, reps: "10"),
            Exercise(name: "Leg Press", icon: "figure.strengthtraining.functional", sets: 3, reps: "12"),
            Exercise(name: "Walking Lunges", icon: "figure.walk", sets: 3, reps: "12 each"),
            Exercise(name: "Leg Curl", icon: "figure.strengthtraining.functional", sets: 3, reps: "12"),
            Exercise(name: "Calf Raises", icon: "figure.walk", sets: 4, reps: "15"),
        ],
        .shoulders: [
            Exercise(name: "Overhead Press", icon: "figure.strengthtraining.traditional", sets: 4, reps: "8"),
            Exercise(name: "Lateral Raises", icon: "figure.boxing", sets: 3, reps: "15"),
            Exercise(name: "Rear Delt Flyes", icon: "figure.boxing", sets: 3, reps: "15"),
            Exercise(name: "Arnold Press", icon: "figure.strengthtraining.traditional", sets: 3, reps: "10"),
            Exercise(name: "Upright Row", icon: "figure.boxing", sets: 3, reps: "12"),
        ],
        .arms: [
            Exercise(name: "Barbell Curl", icon: "dumbbell.fill", sets: 3, reps: "12"),
            Exercise(name: "Hammer Curl", icon: "dumbbell.fill", sets: 3, reps: "12"),
            Exercise(name: "Tricep Pushdown", icon: "dumbbell.fill", sets: 3, reps: "15"),
            Exercise(name: "Skull Crushers", icon: "dumbbell.fill", sets: 3, reps: "12"),
            Exercise(name: "Close-Grip Bench Press", icon: "figure.strengthtraining.traditional", sets: 3, reps: "10"),
        ],
        .core: [
            Exercise(name: "Plank", icon: "figure.core.training", sets: 3, reps: "45 sec"),
            Exercise(name: "Hanging Leg Raise", icon: "figure.core.training", sets: 3, reps: "12"),
            Exercise(name: "Cable Crunch", icon: "figure.core.training", sets: 3, reps: "15"),
            Exercise(name: "Russian Twists", icon: "figure.core.training", sets: 3, reps: "20"),
            Exercise(name: "Bicycle Crunches", icon: "figure.core.training", sets: 3, reps: "20"),
            Exercise(name: "Ab Wheel Rollout", icon: "figure.core.training", sets: 3, reps: "10"),
        ],
        .cardio: [
            Exercise(name: "Treadmill Intervals", icon: "figure.run", sets: 1, reps: "20 min"),
            Exercise(name: "Rowing Machine", icon: "figure.rower", sets: 1, reps: "15 min"),
            Exercise(name: "Jump Rope", icon: "figure.jumprope", sets: 4, reps: "2 min"),
            Exercise(name: "Stair Climber", icon: "figure.stairs", sets: 1, reps: "15 min"),
            Exercise(name: "Burpees", icon: "figure.highintensity.intervaltraining", sets: 4, reps: "15"),
            Exercise(name: "Battle Ropes", icon: "figure.highintensity.intervaltraining", sets: 4, reps: "30 sec"),
        ],
    ]
}

#Preview {
    CustomWorkoutBuilderView { _ in }
}
