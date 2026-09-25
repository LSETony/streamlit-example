import WidgetKit
import SwiftUI

/// Home Screen widget — a rotating pick from the club's real workout_cards
/// table (public-read, same table WorkoutsView shows), changing once a
/// day. Deliberately doesn't show anything member-specific (streak, visit
/// count, ...): the widget extension runs in its own sandboxed process
/// without an App Group, so it has no access to this device's
/// DeviceUser.id the way the host app does — wiring that up would need an
/// App Group entitlement, which (like Sign in with Apple — see
/// AuthService.isAppleSignInConfigured's comment) may not provision on a
/// free/personal Apple Developer team. A shared, non-personal pick avoids
/// that risk entirely while still being real, live server data.
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
                .containerBackground(for: .widget) { Color.appBackground }
        }
        .configurationDisplayName("Workout of the Day")
        .description("A fresh pick from the core. library, every day.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WorkoutOfTheDayWidgetView: View {
    let entry: WorkoutOfTheDayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WORKOUT OF THE DAY")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.appAccent)
            Text(entry.title)
                .font(.system(size: family == .systemSmall ? 15 : 18, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(family == .systemSmall ? 3 : 2)
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                Text(entry.duration)
                Text("·")
                Text(entry.level)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.65))
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
