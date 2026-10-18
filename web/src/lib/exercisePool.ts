export interface PoolExercise {
  name: string;
  icon: string;
  sets: number;
  reps: string;
}

export interface WorkoutZone {
  id: string;
  name: string;
}

/// Ported 1:1 from CustomWorkoutBuilderView.swift's static WorkoutZone enum
/// + exercisePool — this data lives in the iOS app's source, not Supabase,
/// so it's duplicated here rather than fetched.
export const workoutZones: WorkoutZone[] = [
  { id: "chest", name: "Chest" },
  { id: "back", name: "Back" },
  { id: "legs", name: "Legs" },
  { id: "shoulders", name: "Shoulders" },
  { id: "arms", name: "Arms" },
  { id: "core", name: "Core" },
  { id: "cardio", name: "Cardio" },
];

export const exercisePool: Record<string, PoolExercise[]> = {
  chest: [
    { name: "Barbell Bench Press", icon: "🏋️", sets: 4, reps: "8" },
    { name: "Incline Dumbbell Press", icon: "🏋️", sets: 3, reps: "10" },
    { name: "Push-ups", icon: "🏋️", sets: 3, reps: "15" },
    { name: "Cable Flyes", icon: "🏋️", sets: 3, reps: "12" },
    { name: "Dips", icon: "🏋️", sets: 3, reps: "10" },
    { name: "Chest Press Machine", icon: "🏋️", sets: 3, reps: "12" },
  ],
  back: [
    { name: "Deadlift", icon: "🏋️", sets: 4, reps: "6" },
    { name: "Pull-ups", icon: "🏋️", sets: 3, reps: "8" },
    { name: "Lat Pulldown", icon: "🚣", sets: 3, reps: "12" },
    { name: "Seated Cable Row", icon: "🚣", sets: 3, reps: "12" },
    { name: "Bent-over Row", icon: "🏋️", sets: 3, reps: "10" },
    { name: "Face Pulls", icon: "🚣", sets: 3, reps: "15" },
  ],
  legs: [
    { name: "Barbell Squats", icon: "🏋️", sets: 4, reps: "8" },
    { name: "Romanian Deadlift", icon: "🏋️", sets: 3, reps: "10" },
    { name: "Leg Press", icon: "🏋️", sets: 3, reps: "12" },
    { name: "Walking Lunges", icon: "🚶", sets: 3, reps: "12 each" },
    { name: "Leg Curl", icon: "🏋️", sets: 3, reps: "12" },
    { name: "Calf Raises", icon: "🚶", sets: 4, reps: "15" },
  ],
  shoulders: [
    { name: "Overhead Press", icon: "🏋️", sets: 4, reps: "8" },
    { name: "Lateral Raises", icon: "🥊", sets: 3, reps: "15" },
    { name: "Rear Delt Flyes", icon: "🥊", sets: 3, reps: "15" },
    { name: "Arnold Press", icon: "🏋️", sets: 3, reps: "10" },
    { name: "Upright Row", icon: "🥊", sets: 3, reps: "12" },
  ],
  arms: [
    { name: "Barbell Curl", icon: "🏋️", sets: 3, reps: "12" },
    { name: "Hammer Curl", icon: "🏋️", sets: 3, reps: "12" },
    { name: "Tricep Pushdown", icon: "🏋️", sets: 3, reps: "15" },
    { name: "Skull Crushers", icon: "🏋️", sets: 3, reps: "12" },
    { name: "Close-Grip Bench Press", icon: "🏋️", sets: 3, reps: "10" },
  ],
  core: [
    { name: "Plank", icon: "🧘", sets: 3, reps: "45 sec" },
    { name: "Hanging Leg Raise", icon: "🧘", sets: 3, reps: "12" },
    { name: "Cable Crunch", icon: "🧘", sets: 3, reps: "15" },
    { name: "Russian Twists", icon: "🧘", sets: 3, reps: "20" },
    { name: "Bicycle Crunches", icon: "🧘", sets: 3, reps: "20" },
    { name: "Ab Wheel Rollout", icon: "🧘", sets: 3, reps: "10" },
  ],
  cardio: [
    { name: "Treadmill Intervals", icon: "🏃", sets: 1, reps: "20 min" },
    { name: "Rowing Machine", icon: "🚣", sets: 1, reps: "15 min" },
    { name: "Jump Rope", icon: "🤾", sets: 4, reps: "2 min" },
    { name: "Stair Climber", icon: "🏃", sets: 1, reps: "15 min" },
    { name: "Burpees", icon: "🔥", sets: 4, reps: "15" },
    { name: "Battle Ropes", icon: "🔥", sets: 4, reps: "30 sec" },
  ],
};
