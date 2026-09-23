import SwiftUI

struct StoreView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var search = ""
    @State private var isShowingCart = false
    @State private var isShowingFilters = false
    @State private var maxPrice: Double = 500
    @State private var selectedIngredients: Set<String> = []
    @State private var sortOption = "Name"
    private let sortOptions = ["Name", "Price: low to high", "Price: high to low"]

    private var priceBound: Double {
        Double(appState.products.map(\.price).max() ?? 200)
    }

    private var allIngredients: [String] {
        Array(Set(appState.products.flatMap { $0.ingredients.map(\.name) })).sorted()
    }

    private var filteredProducts: [Product] {
        let filtered = appState.products.filter { product in
            let matchesSearch = search.isEmpty
                || product.name.localizedCaseInsensitiveContains(search)
                || product.ingredients.contains { $0.name.localizedCaseInsensitiveContains(search) }
            let matchesPrice = Double(product.price) <= maxPrice
            let productIngredientNames = Set(product.ingredients.map(\.name))
            let matchesIngredients = selectedIngredients.isEmpty || !productIngredientNames.isDisjoint(with: selectedIngredients)
            return matchesSearch && matchesPrice && matchesIngredients
        }
        switch sortOption {
        case "Price: low to high":
            return filtered.sorted { $0.price < $1.price }
        case "Price: high to low":
            return filtered.sorted { $0.price > $1.price }
        default:
            return filtered.sorted { $0.name < $1.name }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Supplements")
                    .font(.brand(32))
                    .foregroundStyle(.white)
                SearchToolRow(search: $search, sortOptions: sortOptions, onSortSelect: { sortOption = $0 }) { isShowingFilters = true }
                productGrid
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { isShowingCart = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "cart.fill").foregroundStyle(Color.appAccent)
                        if appState.cartCount > 0 {
                            Text("\(appState.cartCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 15, minHeight: 15)
                                .background(Color.appAccent)
                                .clipShape(Circle())
                                .offset(x: 10, y: -8)
                        }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
            }
        }
        .navigationDestination(isPresented: $isShowingCart) {
            CartView()
        }
        .sheet(item: $selectedProduct) { product in
            NavigationStack { ProductDetailView(product: product) }
        }
        .sheet(isPresented: $isShowingFilters) {
            PriceTagFilterSheet(
                title: "Filter supplements",
                maxPrice: $maxPrice,
                priceBound: priceBound,
                sectionLabel: "Ingredients",
                allOptions: allIngredients,
                selectedOptions: $selectedIngredients
            )
        }
    }

    private var productGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(filteredProducts) { product in
                ProductTile(product: product) {
                    selectedProduct = product
                } onAdd: {
                    appState.addToCart(product)
                    isShowingCart = true
                }
            }
        }
    }
}

private struct ProductTile: View {
    let product: Product
    var onOpen: () -> Void
    var onAdd: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                Spacer(minLength: 60)
                Text(product.name)
                    .font(.brand(16))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack {
                    Text("\(product.price)$")
                        .font(.digitalTimer(20))
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.appAccent).interactive(), in: Circle())
                }
            }
            .padding(16)
            .aspectRatio(186.0 / 196.0, contentMode: .fit)
            .frame(maxWidth: .infinity, alignment: .bottomLeading)
            .overlay(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous).stroke(Color.appDivider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct ProductDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let product: Product
    @State private var isShowingCart = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous).fill(Color.appSurfaceElevated)
                    Text(product.abbr).font(.digitalTimer(40)).foregroundStyle(Color.appTextSecondary)
                }
                .frame(height: 150)

                VStack(alignment: .leading, spacing: 5) {
                    Text(product.tag.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.4).foregroundStyle(product.tagColor)
                    Text(product.name).font(.brand(26)).foregroundStyle(.white)
                    Text("\(product.form) · \(product.dose) · \(product.count)").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                }

                HStack(spacing: 10) {
                    Text("\(product.price)$").font(.digitalTimer(28)).foregroundStyle(.white)
                    Text("or \(product.subscriptionPrice)$ on subscription").font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
                }

                Text(product.desc).font(.system(size: 14)).foregroundStyle(Color.appTextSecondary).lineSpacing(4)

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowLabel(text: "Ingredients per serving")
                        ForEach(product.ingredients) { ingredient in
                            HStack {
                                Text(ingredient.name).font(.system(size: 14)).foregroundStyle(.white)
                                Spacer()
                                Text(ingredient.amount).font(.digitalTimer(13)).foregroundStyle(Color.appTextSecondary)
                            }
                            .padding(.bottom, 8)
                            AppDivider()
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        EyebrowLabel(text: "Benefits")
                        Text(product.benefits).font(.system(size: 14)).foregroundStyle(Color.appTextSecondary).lineSpacing(4)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        EyebrowLabel(text: "Risks and cautions", color: .appWarning)
                        Text(product.risks).font(.system(size: 14)).foregroundStyle(Color.appTextSecondary).lineSpacing(4)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        EyebrowLabel(text: "Interactions", color: .appWarning)
                        Text(product.interactions).font(.system(size: 14)).foregroundStyle(Color.appTextSecondary).lineSpacing(4)
                    }
                }
                .appCard(padding: 20)

                PrimaryButton(title: "Add to cart") {
                    appState.addToCart(product)
                    isShowingCart = true
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
        .navigationDestination(isPresented: $isShowingCart) {
            CartView()
        }
    }
}

#Preview {
    NavigationStack { StoreView() }
        .environmentObject(AppState())
}
