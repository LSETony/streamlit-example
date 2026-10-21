import WidgetKit
import SwiftUI

/// A Home Screen widget showing this member's latest Apple Health
/// readings — heart rate, steps, sleep (small/medium add hydration and
/// BMI). Like ProgressAchievementsWidget, this reads a snapshot the main
/// app writes to the shared App Group container (see
/// AppState+Health.swift's refreshHealthMetrics()) instead of querying
/// HealthKit itself — no HealthKit entitlement needed in the widget
/// extension, works offline, always reflects whatever the app last synced.
struct HealthEntry: TimelineEntry {
    let date: Date
    let snapshot: HealthSnapshot
}

struct HealthProvider: TimelineProvider {
    func placeholder(in context: Context) -> HealthEntry {
        HealthEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthEntry) -> Void) {
        completion(HealthEntry(date: Date(), snapshot: SharedHealthStore.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthEntry>) -> Void) {
        let entry = HealthEntry(date: Date(), snapshot: SharedHealthStore.load() ?? .placeholder)
        // The app resyncs this and reloads the widget directly whenever
        // HealthMetricsView refreshes — this hourly timeline is just a
        // safety net, same reasoning as ProgressAchievementsWidget's.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }
}

struct HealthMetricsWidget: Widget {
    let kind = "HealthMetricsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HealthProvider()) { entry in
            HealthMetricsWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBrandBackground() }
        }
        .configurationDisplayName("Health Metrics")
        .description("Your latest heart rate, steps, sleep and hydration from Apple Health.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HealthMetricsWidgetView: View {
    let entry: HealthEntry
    @Environment(\.widgetFamily) private var family

    private var snapshot: HealthSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .systemSmall: smallBody
        default: mediumBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.appAccent)
                    .symbolEffect(.pulse)
                Text("HEALTH")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer(minLength: 0)
            stat(icon: "heart.fill", value: snapshot.heartRateBPM.map { "\($0)" }, unit: "bpm", color: .appAccent)
            stat(icon: "figure.walk", value: snapshot.steps.map { "\($0)" }, unit: "steps", color: .appAccentPurple)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    private var mediumBody: some View {
        HStack(spacing: 0) {
            stat(icon: "heart.fill", value: snapshot.heartRateBPM.map { "\($0)" }, unit: "bpm", color: .appAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
            stat(icon: "figure.walk", value: snapshot.steps.map { "\($0)" }, unit: "steps", color: .appAccentPurple)
                .frame(maxWidth: .infinity, alignment: .leading)
            stat(
                icon: "moon.stars.fill",
                value: snapshot.sleepMinutes.map { "\($0 / 60)h\($0 % 60)m" },
                unit: "sleep", color: .appAccentPurple
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            stat(icon: "drop.fill", value: snapshot.hydrationML.map { "\($0)" }, unit: "ml", color: .appAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }

    private func stat(icon: String, value: String?, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            Text(value ?? "—")
                .font(.digitalTimer(family == .systemSmall ? 20 : 16))
                .foregroundStyle(.white)
            Text(unit.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(Color.appTextSecondary)
        }
    }
}

#Preview(as: .systemMedium) {
    HealthMetricsWidget()
} timeline: {
    HealthEntry(date: Date(), snapshot: .placeholder)
}
