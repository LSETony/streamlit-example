import SwiftUI

struct NutritionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showAddMeal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                macrosCard
                waterCard
                mealsSection
                if appState.proteinTarget - appState.proteinCurrent > 0 {
                    Text("Protein is running \(appState.proteinTarget - appState.proteinCurrent) g under target on training days.")
                        .font(.system(size: 12))
                        .foregroundStyle(.appTextTertiary)
                }
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.foregroundStyle(.appAccent)
            }
        }
        .sheet(isPresented: $showAddMeal) {
            AddMealSheet()
        }
    }

    private var macrosCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                macroColumn(label: "PROTEIN", current: appState.proteinCurrent, target: appState.proteinTarget, color: .appAccent)
                macroColumn(label: "CARBS", current: appState.carbsCurrent, target: appState.carbsTarget, color: .white)
                macroColumn(label: "FAT", current: appState.fatCurrent, target: appState.fatTarget, color: .white)
            }
        }
        .appCard()
    }

    private func macroColumn(label: String, current: Int, target: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.appTextSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(current)").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("/\(target)").font(.system(size: 12)).foregroundStyle(.appTextTertiary)
            }
            ProgressBarView(value: Double(current) / Double(target), color: color, height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var waterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EyebrowLabel(text: "Water")
                Spacer()
                Text(String(format: "%.2f L", appState.waterLiters))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Button { appState.removeWater() } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().stroke(Color.white.opacity(0.25)))
                }
                .buttonStyle(.plain)
                Button { appState.addWater() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.appAccent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 6) {
                ForEach(0..<appState.waterGlassesTotal, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(i < appState.waterGlassesFilled ? Color.appAccent : Color.white.opacity(0.08))
                        .frame(height: 28)
                }
            }
        }
        .appCard()
    }

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderRow(title: "Meals today", trailing: "+ Add meal") {
                showAddMeal = true
            }
            ForEach(appState.meals) { meal in
                HStack(spacing: 14) {
                    Text(meal.time)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.appTextSecondary)
                        .frame(width: 44, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        Text(meal.subtitle).font(.system(size: 12)).foregroundStyle(.appTextSecondary)
                    }
                    Spacer()
                    Text("\(meal.calories)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Button {
                        appState.removeMeal(meal)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.appTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
            }
        }
    }
}

private struct AddMealSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var calories: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Name", text: $name)
                    TextField("Details (e.g. 30 g protein)", text: $subtitle)
                    TextField("Calories", text: $calories)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.addMeal(name: name.isEmpty ? "Meal" : name, subtitle: subtitle, calories: Int(calories) ?? 0)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { NutritionView() }
        .environmentObject(AppState())
}
