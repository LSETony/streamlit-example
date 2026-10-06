import SwiftUI
import Charts

/// Opened by tapping the "Your Progress" card on Home — a thin wrapper
/// around ProgressContentView (the actual content, shared with the
/// Progress tab — see ProgressTabView.swift) with a NavigationStack/Done
/// button since this presents as a sheet.
struct ProgressDetailView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                ProgressContentView()
                    .screenPadding()
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
        }
    }
}

/// Streak + achievements, muscle-mass growth chart, InBody body
/// composition (trend chart, scan history, "Log scan"), supplement
/// recommendations, this-week totals and workout history — every real
/// metric this app tracks about a member's own progress, in one place.
/// Used by both ProgressDetailView (Home's sheet) and ProgressTabView (the
/// tab), so there's exactly one version of this content to keep real
/// instead of two screens quietly drifting apart.
struct ProgressContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedProduct: Product?
    @State private var isShowingProgressPhotos = false
    @State private var isShowingLogScan = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            streakSection
            todayStatsSection
            historySection
            achievementsSection
            muscleMassCard
            bodyCompositionSection
            vitaminRecommendationsSection
        }
        .sheet(item: $selectedProduct) { product in
            NavigationStack { ProductDetailView(product: product) }
        }
        .sheet(isPresented: $isShowingProgressPhotos) {
            ProgressPhotosView()
        }
        .sheet(isPresented: $isShowingLogScan) {
            LogInBodyScanView()
        }
    }

    // MARK: Streak + achievements

    private var streakSection: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundStyle(Color.appAccent)
                    Text("\(appState.streakDays)").font(.digitalTimer(32)).foregroundStyle(.white)
                }
                Text("day streak")
                    .font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Button { isShowingProgressPhotos = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Photos")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(.appAccentPurple).interactive(), in: Capsule())
        }
        .glassCard(padding: 20)
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Achievements")
            GlassEffectContainer(spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(appState.achievements) { achievement in
                        achievementTile(achievement)
                    }
                }
            }
        }
    }

    private func achievementTile(_ achievement: Achievement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: achievement.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(achievement.isUnlocked ? Color.appAccent : Color.appTextSecondary)
            Text(achievement.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(achievement.isUnlocked ? .white : Color.appTextSecondary)
            Text(achievement.detail)
                .font(.system(size: 11))
                .foregroundStyle(Color.appTextSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .opacity(achievement.isUnlocked ? 1 : 0.5)
        .glassEffect(achievement.isUnlocked ? .regular.tint(.appAccent.opacity(0.25)) : .regular, in: RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: Muscle mass chart

    private var muscleMassCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Muscle Mass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let first = appState.muscleMassHistory.first, let last = appState.muscleMassHistory.last {
                    let delta = last.kg - first.kg
                    Text(String(format: "%+.1f kg", delta))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(delta >= 0 ? Color.appSuccess : Color.appAccent)
                }
            }
            if let last = appState.muscleMassHistory.last {
                Text(String(format: "%.1f kg", last.kg))
                    .font(.digitalTimer(34))
                    .foregroundStyle(.white)
            }
            Chart(appState.muscleMassHistory) { entry in
                AreaMark(x: .value("Week", entry.label), y: .value("Muscle Mass", entry.kg))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(colors: [Color.appAccent.opacity(0.35), Color.appAccent.opacity(0)], startPoint: .top, endPoint: .bottom)
                    )
                LineMark(x: .value("Week", entry.label), y: .value("Muscle Mass", entry.kg))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.appAccent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(x: .value("Week", entry.label), y: .value("Muscle Mass", entry.kg))
                    .foregroundStyle(Color.appAccent)
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisGridLine().foregroundStyle(Color.appDivider)
                    AxisValueLabel().foregroundStyle(Color.appTextSecondary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .glassCard(padding: 20)
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: Body composition (InBody)

    private var bodyCompositionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                EyebrowLabel(text: "Body Composition")
                Spacer()
                Button { isShowingLogScan = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Log scan")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.appAccentPurple).interactive(), in: Capsule())
            }
            GlassEffectContainer(spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    statTile(value: String(format: "%.1f%%", appState.bodyFatPercent), label: "Body Fat")
                    statTile(value: String(format: "%.1f%%", appState.totalBodyWaterPercent), label: "Total Body Water")
                    statTile(value: "\(appState.visceralFatIndex)", label: "Visceral Fat Index")
                    statTile(value: "\(appState.basalMetabolicRate)", label: "Basal Metabolic Rate")
                }
            }

            if appState.inBodyHistory.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Body fat trend")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Chart(appState.inBodyHistory.sorted(by: { $0.scannedAt < $1.scannedAt })) { entry in
                        AreaMark(x: .value("Date", entry.scannedAt), y: .value("Body Fat %", entry.bodyFatPercent))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(colors: [Color.appAccentPurple.opacity(0.35), Color.appAccentPurple.opacity(0)], startPoint: .top, endPoint: .bottom)
                            )
                        LineMark(x: .value("Date", entry.scannedAt), y: .value("Body Fat %", entry.bodyFatPercent))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.appAccentPurple)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        PointMark(x: .value("Date", entry.scannedAt), y: .value("Body Fat %", entry.bodyFatPercent))
                            .foregroundStyle(Color.appAccentPurple)
                    }
                    .frame(height: 140)
                    .chartYAxis {
                        AxisMarks(position: .trailing) { _ in
                            AxisGridLine().foregroundStyle(Color.appDivider)
                            AxisValueLabel().foregroundStyle(Color.appTextSecondary)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Color.appTextSecondary)
                        }
                    }
                }
                .glassCard(padding: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
            }

            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(appState.inBodyHistory.sorted(by: { $0.scannedAt > $1.scannedAt })) { entry in
                        inBodyScanRow(entry)
                    }
                }
            }
        }
    }

    private func inBodyScanRow(_ entry: InBodyEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.scannedAt.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("BMR \(entry.basalMetabolicRate) · VFI \(entry.visceralFatIndex)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f%% fat", entry.bodyFatPercent))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
                Text(String(format: "%.1f%% water", entry.totalBodyWaterPercent))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appAccentPurple)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: Vitamin recommendations

    private var vitaminRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Vitamin Recommendations")
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(appState.products) { product in
                        vitaminRow(product)
                    }
                }
            }
        }
    }

    private func vitaminRow(_ product: Product) -> some View {
        Button {
            selectedProduct = product
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.appSurfaceElevated)
                    Text(product.abbr).font(.digitalTimer(15)).foregroundStyle(Color.appTextSecondary)
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(product.tag)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(product.tagColor)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(14)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Today / week totals

    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "This week")
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    statTile(value: "\(appState.totalSetsThisWeek)", label: "Sets")
                    statTile(value: "\(appState.totalMinutesThisWeek)", label: "Mins")
                    statTile(value: "\(appState.totalCaloriesThisWeek)", label: "Kcal")
                }
            }
        }
    }

    // MARK: Workout history

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Workout history")
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(appState.workoutHistory) { entry in
                        historyRow(entry)
                    }
                }
            }
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.digitalTimer(20)).foregroundStyle(.white)
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.4).foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    ProgressDetailView()
        .environmentObject(AppState())
}
