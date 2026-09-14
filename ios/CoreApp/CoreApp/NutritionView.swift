import SwiftUI

struct NutritionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                kcalCard
                waterCard
                mealsSection
                insightCard
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            EyebrowLabel(text: "Sunday · target \(formatted(appState.kcalTarget)) kcal")
            Text("Nutrition")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var kcalCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom, spacing: 12) {
                Text("\(appState.kcalInToday)")
                    .font(.digitalTimer(46))
                    .foregroundStyle(.white)
                Text("of \(formatted(appState.kcalTarget)) kcal · \(appState.kcalLeft) left")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.bottom, 6)
            }
            ProgressBarView(value: Double(appState.kcalInToday) / Double(appState.kcalTarget), color: .appAccent, height: 10)

            HStack(spacing: 12) {
                macroColumn(label: "Protein", current: appState.proteinCurrent, target: appState.proteinTarget, color: .appAccent)
                macroColumn(label: "Carbs", current: appState.carbsCurrent, target: appState.carbsTarget, color: .appTextSecondary)
                macroColumn(label: "Fat", current: appState.fatCurrent, target: appState.fatTarget, color: .appTextSecondary)
            }
        }
        .appCard(padding: 20)
    }

    private func macroColumn(label: String, current: Int, target: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.system(size: 11)).tracking(0.4).foregroundStyle(Color.appTextSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(current)").font(.digitalTimer(20)).foregroundStyle(.white)
                Text("/\(target)").font(.system(size: 11)).foregroundStyle(Color.appTextSecondary)
            }
            ProgressBarView(value: Double(current) / Double(target), color: color, height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var waterCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    EyebrowLabel(text: "Water")
                    Text(String(format: "%.2f L", appState.waterLiters))
                        .font(.digitalTimer(24))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button { appState.removeWater() } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(Color.appDivider, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Button { appState.addWater() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.appAccent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 5) {
                ForEach(0..<appState.waterGlassesTotal, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(i < appState.waterGlassesFilled ? Color.appAccent : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.appDivider, lineWidth: 1))
                        .frame(height: 26)
                }
            }
        }
        .appCard(padding: 20)
    }

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderRow(title: "Meals today", trailing: "+ Add meal") {
                appState.addMeal()
            }
            ForEach(appState.meals) { meal in
                HStack(spacing: 14) {
                    Text(meal.time)
                        .font(.digitalTimer(15))
                        .foregroundStyle(Color.appTextSecondary)
                        .frame(width: 44, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        Text("\(meal.protein) g protein").font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
                    }
                    Spacer()
                    Text("\(meal.calories)")
                        .font(.digitalTimer(17))
                        .foregroundStyle(.white)
                    Button {
                        appState.removeMeal(meal)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
            }
        }
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FROM YOUR LAST PANEL")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Color.appAccent)
            Text("Protein is running 40 g under target on training days. Elena added a casein shake to the evening slot.")
                .font(.system(size: 14))
                .foregroundStyle(.white)
        }
        .padding(18)
        .background(Color.appAccentDim)
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous).stroke(Color.appAccent, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    private func formatted(_ n: Int) -> String {
        let s = String(n)
        guard s.count > 3 else { return s }
        return String(s.dropLast(3)) + " " + s.suffix(3)
    }
}

#Preview {
    NavigationStack { NutritionView() }
        .environmentObject(AppState())
}
