import SwiftUI

struct StoreView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var ordered = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                bundleCard
                productGrid
                cartCard
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
        .sheet(item: $selectedProduct) { product in
            NavigationStack { ProductDetailView(product: product) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            EyebrowLabel(text: "Pickup at the club · free")
            Text("Store")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var bundleCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR BUNDLE · BUILT FROM THE \(appState.lastScanDate) PANEL")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Color.appAccent)
            Text("Iron + D3/K2 + Magnesium")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("₽4 180").font(.digitalTimer(22)).foregroundStyle(.white)
                    Text("₽3 550 monthly · cancel anytime").font(.system(size: 11)).foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                Button { appState.addBundle() } label: {
                    Text("SUBSCRIBE")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.appAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color.appSurface)
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous).stroke(Color.appAccent, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    private var productGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(appState.products) { product in
                ProductTile(product: product) {
                    selectedProduct = product
                } onAdd: {
                    appState.addToCart(product)
                }
            }
        }
    }

    private var cartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EyebrowLabel(text: "Cart · \(appState.cartCount) items")
                Spacer()
                Button("CLEAR") { appState.clearCart() }
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(Color.appTextSecondary)
            }
            VStack(spacing: 10) {
                ForEach(appState.cart) { line in
                    HStack {
                        Text(line.name).font(.system(size: 14)).foregroundStyle(.white)
                        Spacer()
                        Text("₽\(line.price)").font(.digitalTimer(14)).foregroundStyle(Color.appTextSecondary)
                        Button { appState.removeFromCart(line) } label: {
                            Text("×").font(.system(size: 16)).foregroundStyle(Color.appTextSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 10)
                    AppDivider()
                }
            }
            HStack(alignment: .lastTextBaseline) {
                Text("Total · pick up at reception").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                Spacer()
                Text("₽\(appState.cartTotal)").font(.digitalTimer(24)).foregroundStyle(.white)
            }
            PrimaryButton(title: checkoutLabel, isEnabled: appState.cartCount > 0) {
                ordered = true
            }
        }
        .appCard(padding: 20)
    }

    private var checkoutLabel: String {
        if ordered { return "✓ Ready for pickup today" }
        return appState.cartCount > 0 ? "Reserve for club pickup" : "Cart is empty"
    }
}

private struct ProductTile: View {
    let product: Product
    var onOpen: () -> Void
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onOpen) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.appSurfaceElevated)
                    Text(product.abbr).font(.digitalTimer(16)).foregroundStyle(Color.appTextSecondary)
                }
                .frame(height: 60)
            }
            .buttonStyle(.plain)

            Text(product.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(minHeight: 34, alignment: .top)

            Text(product.tag.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.3)
                .foregroundStyle(product.tagColor)

            HStack {
                Text("₽\(product.price)")
                    .font(.digitalTimer(15))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.appAccent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

private struct ProductDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let product: Product

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
                    Text(product.name).font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                    Text("\(product.form) · \(product.dose) · \(product.count)").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                }

                HStack(spacing: 10) {
                    Text("₽\(product.price)").font(.digitalTimer(28)).foregroundStyle(.white)
                    Text("or ₽\(product.subscriptionPrice) on subscription").font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
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

                HStack(spacing: 10) {
                    PrimaryButton(title: "Add to cart") {
                        appState.addToCart(product)
                    }
                    Button { dismiss() } label: {
                        Text("Cart \(appState.cartCount)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .overlay(Capsule().stroke(Color.appDivider, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
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

#Preview {
    NavigationStack { StoreView() }
        .environmentObject(AppState())
}
