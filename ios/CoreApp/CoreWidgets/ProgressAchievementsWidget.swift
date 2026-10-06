import WidgetKit
import SwiftUI

/// A personal "dashboard" Home Screen widget — this member's own streak,
/// weekly sets/time/calories and unlocked-achievement count. Unlike
/// WorkoutOfTheDayWidget (deliberately public data, no App Group needed),
/// this is genuinely personal, so it reads a snapshot the main app writes
/// to a shared App Group container (see SharedProgressStore.swift) instead
/// of hitting the network itself — no credentials in the widget, works
/// offline, and always reflects whatever the app last saw.
struct ProgressEntry: TimelineEntry {
    let date: Date
    let snapshot: ProgressSnapshot
}

struct ProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProgressEntry) -> Void) {
        completion(ProgressEntry(date: Date(), snapshot: SharedProgressStore.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProgressEntry>) -> Void) {
        let entry = ProgressEntry(date: Date(), snapshot: SharedProgressStore.load() ?? .placeholder)
        // AppState.syncProgressWidget() writes a fresh snapshot and reloads
        // this widget directly the moment streak/workout state changes —
        // this hourly refresh is just a safety net in case that signal is
        // ever missed (e.g. the app was force-quit mid-write).
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }
}

struct ProgressAchievementsWidget: Widget {
    let kind = "ProgressAchievementsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProgressProvider()) { entry in
            ProgressAchievementsWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBrandBackground() }
        }
        .configurationDisplayName("Progress & Achievements")
        .description("Your streak, weekly stats and unlocked achievements at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ProgressAchievementsWidgetView: View {
    let entry: ProgressEntry
    @Environment(\.widgetFamily) private var family

    private var snapshot: ProgressSnapshot { entry.snapshot }
    private var achievementProgress: Double {
        guard snapshot.totalAchievements > 0 else { return 0 }
        return Double(snapshot.unlockedAchievements) / Double(snapshot.totalAchievements)
    }
    private var streakProgress: Double { min(1, Double(snapshot.streakDays) / 7.0) }

    var body: some View {
        switch family {
        case .systemSmall: smallBody
        case .systemLarge: largeBody
        default: mediumBody
        }
    }

    // MARK: Small — just the streak ring

    private var smallBody: some View {
        VStack(spacing: 10) {
            ringView(progress: streakProgress, size: 64) {
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.appAccent)
                        .symbolEffect(.pulse)
                    Text("\(snapshot.streakDays)")
                        .font(.digitalTimer(22))
                        .foregroundStyle(.white)
                }
            }
            Text("day streak")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
    }

    // MARK: Medium — streak ring + weekly stats + achievement count

    private var mediumBody: some View {
        HStack(spacing: 16) {
            ringView(progress: streakProgress, size: 74) {
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.appAccent)
                        .symbolEffect(.pulse)
                    Text("\(snapshot.streakDays)")
                        .font(.digitalTimer(24))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("THIS WEEK")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.appTextSecondary)
                statRow(icon: "repeat", value: "\(snapshot.weeklySets)", unit: "sets")
                statRow(icon: "clock.fill", value: "\(snapshot.weeklyMinutes)", unit: "min")
                statRow(icon: "flame", value: "\(snapshot.weeklyCalories)", unit: "kcal")
            }

            Spacer(minLength: 0)

            VStack(spacing: 5) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.appAccentPurple)
                    .symbolEffect(.variableColor.iterative)
                Text("\(snapshot.unlockedAchievements)/\(snapshot.totalAchievements)")
                    .font(.digitalTimer(16))
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Large — full dashboard

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("core.")
                    .font(.brand(16))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                if let title = snapshot.lastWorkoutTitle {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 18) {
                ringView(progress: streakProgress, size: 82) {
                    VStack(spacing: 0) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(Color.appAccent)
                            .symbolEffect(.pulse)
                        Text("\(snapshot.streakDays)")
                            .font(.digitalTimer(26))
                            .foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(snapshot.streakDays)-day streak")
                        .font(.brand(18))
                        .foregroundStyle(.white)
                    Text("\(snapshot.totalWorkouts) workouts logged")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                Image(systemName: "trophy.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.appAccentPurple)
                    .symbolEffect(.variableColor.iterative)
            }

            HStack(spacing: 10) {
                statTile(icon: "repeat", value: "\(snapshot.weeklySets)", label: "SETS")
                statTile(icon: "clock.fill", value: "\(snapshot.weeklyMinutes)", label: "MIN")
                statTile(icon: "flame", value: "\(snapshot.weeklyCalories)", label: "KCAL")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("ACHIEVEMENTS")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.appTextSecondary)
                    Spacer()
                    Text("\(snapshot.unlockedAchievements)/\(snapshot.totalAchievements)")
                        .font(.digitalTimer(13))
                        .foregroundStyle(Color.appAccentPurple)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(
                                LinearGradient(colors: [Color.appAccentPurple, Color.appAccent], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: max(6, geo.size.width * achievementProgress))
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Shared pieces

    private func ringView<Content: View>(progress: Double, size: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [Color.appAccent.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: size * 0.72)
                )
                .frame(width: size * 1.5, height: size * 1.5)
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(0.03, progress))
                .stroke(
                    AngularGradient(colors: [Color.appAccent, Color.appAccentPurple, Color.appAccent], center: .center),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            content()
        }
        .frame(width: size, height: size)
    }

    private func statRow(icon: String, value: String, unit: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .frame(width: 14)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.digitalTimer(13))
                    .foregroundStyle(.white)
                Text(unit)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
    }

    private func statTile(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appAccent)
            Text(value)
                .font(.digitalTimer(17))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview(as: .systemMedium) {
    ProgressAchievementsWidget()
} timeline: {
    ProgressEntry(date: Date(), snapshot: .placeholder)
}
