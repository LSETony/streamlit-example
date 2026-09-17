import SwiftUI

/// The recipe browser — matches the Figma source exactly: title, search +
/// sort/filter row, and a photo-card grid of recipes.
struct FoodRecipesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var isShowingFilters = false
    @State private var maxPrice: Double = 500
    @State private var selectedIngredients: Set<String> = []

    private var priceBound: Double {
        Double(appState.foodRecipes.map(\.price).max() ?? 50)
    }

    private var allIngredients: [String] {
        Array(Set(appState.foodRecipes.flatMap(\.ingredients))).sorted()
    }

    private var filteredRecipes: [FoodRecipe] {
        appState.foodRecipes.filter { recipe in
            let matchesSearch = search.isEmpty
                || recipe.name.localizedCaseInsensitiveContains(search)
                || recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(search) }
            let matchesPrice = Double(recipe.price) <= maxPrice
            let matchesIngredients = selectedIngredients.isEmpty || !Set(recipe.ingredients).isDisjoint(with: selectedIngredients)
            return matchesSearch && matchesPrice && matchesIngredients
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Food recipes")
                    .font(.brand(32))
                    .foregroundStyle(.white)
                SearchToolRow(search: $search) { isShowingFilters = true }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(filteredRecipes) { recipe in
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
        .sheet(isPresented: $isShowingFilters) {
            PriceTagFilterSheet(
                title: "Filter recipes",
                maxPrice: $maxPrice,
                priceBound: priceBound,
                sectionLabel: "Ingredients",
                allOptions: allIngredients,
                selectedOptions: $selectedIngredients
            )
        }
    }
}

private struct RecipeTile: View {
    let recipe: FoodRecipe

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PhotoPlaceholder(icon: "fork.knife")
            LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .bottom, endPoint: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name)
                    .font(.brand(16))
                    .foregroundStyle(.white)
                Text("\(recipe.price)$")
                    .font(.digitalTimer(14))
                    .foregroundStyle(Color.appAccent)
            }
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
