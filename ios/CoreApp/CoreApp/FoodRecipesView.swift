import SwiftUI

/// The recipe browser from the latest Figma pass — search + sort/filter +
/// a photo-card grid of recipes. The existing macro/meal tracker
/// (`NutritionView`) is still reachable from here so that real feature
/// isn't lost, via the "My nutrition" link at the top.
struct FoodRecipesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var showNutrition = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Food recipes")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("My nutrition") { showNutrition = true }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                SearchToolRow(search: $search)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(appState.foodRecipes) { recipe in
                        RecipeTile(recipe: recipe)
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
        .sheet(isPresented: $showNutrition) { NavigationStack { NutritionView() } }
    }
}

private struct RecipeTile: View {
    let recipe: FoodRecipe

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PhotoPlaceholder(style: .food, icon: "fork.knife")
            LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .bottom, endPoint: .center)
            Text(recipe.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(14)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous).stroke(Color.appDivider, lineWidth: 1))
    }
}

#Preview {
    NavigationStack { FoodRecipesView() }
        .environmentObject(AppState())
}
