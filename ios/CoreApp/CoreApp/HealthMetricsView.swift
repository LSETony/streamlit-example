import SwiftUI

/// Opened from Profile's Apple Health card — a dashboard of real HealthKit
/// readings (heart rate, steps, sleep, hydration, BMI, blood pressure,
/// blood glucose), styled with the app's own Liquid Glass cards and
/// digital-display font rather than cloning any particular reference's
/// colorful icon-badge look.
///
/// Every card is a real HealthKit read (see HealthKitService) — nothing
/// here is fabricated. Blood pressure and blood glucose are normal to
/// show "No data" for most members, who have no cuff/CGM logging into
/// Health; this view says so rather than inventing a number. One metric
/// from the reference is deliberately NOT here: Screen Time isn't part of
/// HealthKit at all — it's gated behind Apple's separate Family Controls/
/// DeviceActivity framework, built for parental-control apps monitoring a
/// *different* device in a family, not a fitness app reading its own
/// device's usage, so there's no real way to show it here.
struct HealthMetricsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "Apple Health", color: .appAccentPurple)
                        Text("Health Metrics")
                            .font(.brand(28))
                            .foregroundStyle(.white)
                    }

                    if !appState.appleHealthSyncEnabled {
                        connectPrompt
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            heartRateCard
                            stepsCard
                            sleepCard
                            hydrationCard
                            bmiCard
                            bloodPressureCard
                            bloodGlucoseCard
                        }
                        if let updatedAt = appState.healthMetricsUpdatedAt {
                            Text("Updated \(updatedAt.formatted(date: .omitted, time: .shortened))")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.appTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
            .refreshable { await appState.refreshHealthMetrics() }
            .task { await appState.refreshHealthMetrics() }
        }
    }

    private var connectPrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.appAccent)
            Text("Connect Apple Health to see your heart rate, steps, sleep and more here.")
                .font(.system(size: 14))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Connect Apple Health", color: .appAccentPurple) {
                Task {
                    let granted = await HealthKitService.shared.requestAuthorization()
                    await MainActor.run {
                        appState.appleHealthSyncEnabled = granted
                        if granted { Task { await appState.refreshHealthMetrics() } }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .glassCard(padding: 0)
    }

    // MARK: Cards

    private var heartRateCard: some View {
        metricCard(icon: "heart.fill", color: .appAccent, title: "Heart Rate") {
            if let bpm = appState.heartRateBPM {
                statValue("\(bpm)", unit: "bpm")
            } else {
                noData
            }
        }
    }

    private var stepsCard: some View {
        metricCard(icon: "figure.walk", color: .appAccentPurple, title: "Steps") {
            if let steps = appState.todaySteps {
                statValue("\(steps)", unit: "today")
            } else {
                noData
            }
        }
    }

    private var sleepCard: some View {
        metricCard(icon: "moon.stars.fill", color: .appAccentPurple, title: "Sleep") {
            if let minutes = appState.sleepMinutesLastNight {
                statValue("\(minutes / 60)h \(minutes % 60)m", unit: "last night")
            } else {
                noData
            }
        }
    }

    private var hydrationCard: some View {
        let goalML = 2000
        let value = appState.hydrationML ?? 0
        return metricCard(icon: "drop.fill", color: .appAccent, title: "Hydration") {
            if appState.hydrationML != nil {
                VStack(alignment: .leading, spacing: 8) {
                    statValue("\(value)", unit: "/ \(goalML) ml")
                    ProgressBarView(value: min(1, Double(value) / Double(goalML)), color: .appAccent)
                }
            } else {
                noData
            }
        }
    }

    private var bmiCard: some View {
        metricCard(icon: "gauge.with.dots.needle.50percent", color: .appWarning, title: "BMI") {
            if let bmi = appState.bmi {
                statValue(String(format: "%.1f", bmi), unit: bmiCategory(bmi))
            } else {
                noData
            }
        }
    }

    private var bloodPressureCard: some View {
        metricCard(icon: "waveform.path.ecg", color: .appAccent, title: "Blood Pressure") {
            if let sys = appState.bloodPressureSystolic, let dia = appState.bloodPressureDiastolic {
                statValue("\(sys)/\(dia)", unit: "mmHg")
            } else {
                noData
            }
        }
    }

    private var bloodGlucoseCard: some View {
        metricCard(icon: "drop.triangle.fill", color: .appAccentPurple, title: "Blood Glucose") {
            if let glucose = appState.bloodGlucose {
                statValue("\(glucose)", unit: "mg/dl")
            } else {
                noData
            }
        }
    }

    // MARK: Shared pieces

    private func metricCard<Content: View>(icon: String, color: Color, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(Color.appTextSecondary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(padding: 0)
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func statValue(_ value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value).font(.digitalTimer(22)).foregroundStyle(.white)
            Text(unit).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.appTextSecondary)
        }
    }

    private var noData: some View {
        Text("No data")
            .font(.system(size: 13))
            .foregroundStyle(Color.appTextSecondary.opacity(0.6))
    }

    private func bmiCategory(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "underweight"
        case 18.5..<25: return "normal"
        case 25..<30: return "overweight"
        default: return "high"
        }
    }
}

#Preview {
    HealthMetricsView()
        .environmentObject(AppState())
}
