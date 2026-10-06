import WidgetKit
import SwiftUI

/// Home Screen widget — a rotating pick from the club's real workout_cards
/// table (public-read, same table WorkoutsView shows), changing once a
/// day. Deliberately doesn't show anything member-specific (streak, visit
/// count, ...) — for that, see ProgressAchievementsWidget, which reads the
/// personal snapshot the app writes to the shared App Group container.
/// This one stays a plain network read instead: it doesn't need the
/// member's own data, so there's no reason to depend on the app having
/// synced one first.
struct WorkoutOfTheDayEntry: TimelineEntry {
    let date: Date
    let title: String
    let level: String
    let duration: String

    static let fallback = WorkoutOfTheDayEntry(
        date: Date(), title: "Beginner Body Weight Plan", level: "Beginner", duration: "7 day"
    )
}

struct WorkoutOfTheDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutOfTheDayEntry { .fallback }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutOfTheDayEntry) -> Void) {
        completion(.fallback)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutOfTheDayEntry>) -> Void) {
        Task {
            let entry = await Self.fetchTodaysWorkout()
            let nextRefresh = Calendar.current.nextDate(
                after: Date(), matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime
            ) ?? Date().addingTimeInterval(6 * 3600)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private static func fetchTodaysWorkout() async -> WorkoutOfTheDayEntry {
        struct Row: Decodable { let title: String; let level: String; let duration: String }

        var components = URLComponents(url: WidgetSupabaseConfig.projectURL.appendingPathComponent("rest/v1/workout_cards"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "title,level,duration"),
            URLQueryItem(name: "order", value: "title.asc"),
        ]
        guard let url = components?.url else { return .fallback }

        var request = URLRequest(url: url)
        request.setValue(WidgetSupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(WidgetSupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let rows = try JSONDecoder().decode([Row].self, from: data)
            guard !rows.isEmpty else { return .fallback }
            let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
            let row = rows[dayIndex % rows.count]
            return WorkoutOfTheDayEntry(date: Date(), title: row.title, level: row.level, duration: row.duration)
        } catch {
            return .fallback
        }
    }
}

struct WorkoutOfTheDayWidget: Widget {
    let kind = "WorkoutOfTheDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkoutOfTheDayProvider()) { entry in
            WorkoutOfTheDayWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBrandBackground() }
        }
        .configurationDisplayName("Workout of the Day")
        .description("A fresh pick from the core. library, every day.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WorkoutOfTheDayWidgetView: View {
    let entry: WorkoutOfTheDayEntry
    @Environment(\.widgetFamily) private var family

    /// Same traffic-light convention the rest of the app uses for
    /// good/caution/intense states (appSuccess/appWarning/appAccent) —
    /// applied here to difficulty since no other screen color-codes level
    /// yet, this just reuses the existing tokens rather than inventing new
    /// ones.
    private var levelColor: Color {
        switch entry.level.lowercased() {
        case "beginner": return .appSuccess
        case "intermediate": return .appWarning
        default: return .appAccent
        }
    }

    private var levelIcon: String {
        switch entry.level.lowercased() {
        case "beginner": return "figure.walk"
        case "intermediate": return "figure.strengthtraining.traditional"
        default: return "bolt.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("core.")
                    .font(.brand(13))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Image(systemName: levelIcon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(levelColor)
                    .symbolEffect(.pulse)
                Text(entry.level.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(levelColor)
            }

            Text("WORKOUT OF THE DAY")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.appTextSecondary)

            Text(entry.title)
                .font(.brand(family == .systemSmall ? 16 : 20))
                .foregroundStyle(.white)
                .lineLimit(family == .systemSmall ? 3 : 2)

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                Text(entry.duration)
                    .font(.digitalTimer(13))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular.tint(levelColor.opacity(0.25)), in: Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview(as: .systemSmall) {
    WorkoutOfTheDayWidget()
} timeline: {
    WorkoutOfTheDayEntry.fallback
}
