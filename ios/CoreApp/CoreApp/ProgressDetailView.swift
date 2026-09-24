import SwiftUI
import Charts

/// Opened by tapping the "Your Progress" card on Home. Leads with the
/// muscle-mass growth chart, then an InBody-style body composition
/// readout (body fat, total body water, visceral fat, BMR), then the
/// today/week totals and workout history.
struct ProgressDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var isShowingProgressPhotos = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    streakSection
                    achievementsSection
                    muscleMassCard
                    bodyCompositionSection
                    vitaminRecommendationsSection
                    todayStatsSection
                    historySection
                }
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
            .sheet(item: $selectedProduct) { product in
                NavigationStack { ProductDetailView(product: product) }
            }
            .sheet(isPresented: $isShowingProgressPhotos) {
                ProgressPhotosView()
            }
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
            .glassEffect(.regular.tint(.appAccentPurple), in: Capsule())
        }
        .appCard(padding: 20)
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Achievements")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(appState.achievements) { achievement in
                    achievementTile(achievement)
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
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
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
        .appCard(padding: 20)
    }

    // MARK: Body composition (InBody)

    private var bodyCompositionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Body Composition")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statTile(value: String(format: "%.1f%%", appState.bodyFatPercent), label: "Body Fat")
                statTile(value: String(format: "%.1f%%", appState.totalBodyWaterPercent), label: "Total Body Water")
                statTile(value: "\(appState.visceralFatIndex)", label: "Visceral Fat Index")
                statTile(value: "\(appState.basalMetabolicRate)", label: "Basal Metabolic Rate")
            }
        }
    }

    // MARK: Vitamin recommendations

    private var vitaminRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Vitamin Recommendations")
            VStack(spacing: 10) {
                ForEach(appState.products) { product in
                    vitaminRow(product)
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
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Today / week totals

    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "This week")
            HStack(spacing: 10) {
                statTile(value: "\(appState.totalSetsThisWeek)", label: "Sets")
                statTile(value: "\(appState.totalMinutesThisWeek)", label: "Mins")
                statTile(value: "\(appState.totalCaloriesThisWeek)", label: "Kcal")
            }
        }
    }

    // MARK: Workout history

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Workout history")
            VStack(spacing: 10) {
                ForEach(appState.workoutHistory) { entry in
                    historyRow(entry)
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
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
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
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

#Preview {
    ProgressDetailView()
        .environmentObject(AppState())
}
