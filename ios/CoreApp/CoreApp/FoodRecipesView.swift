import SwiftUI

/// The recipe browser — matches the Figma source exactly: title, search +
/// sort/filter row, and a photo-card grid of recipes.
struct FoodRecipesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Food recipes")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
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
    }
}

private struct RecipeTile: View {
    let recipe: FoodRecipe

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PhotoPlaceholder(icon: "fork.knife")
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
