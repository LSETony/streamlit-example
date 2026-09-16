import SwiftUI

private struct Supplement: Identifiable {
    let id = UUID()
    let name: String
    let price: String
}

/// Figma frame 129:85 "iPhone 16 & 17 Pro Max - 12" — reached via the Home "Store" tile.
struct SupplementsView: View {
    @State private var query = ""

    private let supplements = [
        Supplement(name: "B-Complex", price: "54$"),
        Supplement(name: "Creatine", price: "150$"),
        Supplement(name: "Zinc picolinate", price: "35$"),
        Supplement(name: "Magnesium", price: "85$"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenTitle(title: "Supplements")
                SearchBarRow(text: $query)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(supplements) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle().fill(Theme.placeholder.opacity(0.3))
                                    Image(systemName: "pills").font(.system(size: 14)).foregroundStyle(.white)
                                }
                                .frame(width: 40, height: 40)
                            }
                            Spacer()
                            Text(item.name).font(Theme.Typeface.display(16, weight: .medium)).foregroundStyle(.white)
                            Text(item.price).font(Theme.Typeface.stat(20)).foregroundStyle(.white)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 196)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                                .stroke(Color.white, lineWidth: 1)
                        )
                    }
                }

                HStack {
                    HStack(spacing: 10) {
                        Text("Check").font(Theme.Typeface.display(15, weight: .medium)).foregroundStyle(.white)
                        Text("320$").font(Theme.Typeface.display(15, weight: .semibold)).foregroundStyle(.white)
                    }
                    Spacer()
                    Text("Checkout")
                        .font(Theme.Typeface.display(15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 51)
                        .background(Theme.orange, in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
                }
                .padding(.horizontal, 20)
                .frame(height: 72)
                .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
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
    NavigationStack { SupplementsView() }
}
