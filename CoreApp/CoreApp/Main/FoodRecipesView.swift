import SwiftUI

private struct Recipe: Identifiable {
    let id = UUID()
    let name: String
}

/// Figma frame 163:454 "iPhone 16 & 17 Pro Max - 15" — reached via the Home "Food" tile.
struct FoodRecipesView: View {
    @State private var query = ""

    private let recipes = [
        Recipe(name: "Chicken Cajun"),
        Recipe(name: "Protein pancakes"),
        Recipe(name: "Beef Jerky"),
        Recipe(name: "Carnivore Soup"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenTitle(title: "Food recipes")
                SearchBarRow(text: $query)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(recipes) { recipe in
                        VStack(alignment: .leading, spacing: 8) {
                            Spacer()
                            Text(recipe.name)
                                .font(Theme.Typeface.display(16, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 196, alignment: .bottomLeading)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                                .stroke(Color.white, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 60)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }
}

#Preview {
    NavigationStack { FoodRecipesView() }
}
