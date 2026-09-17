import SwiftUI

struct StoreView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var ordered = false
    @State private var search = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Supplements")
                    .font(.brand(24))
                    .foregroundStyle(.white)
                SearchToolRow(search: $search)
                productGrid
                if appState.cartCount > 0 { checkoutBar }
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

    private var checkoutBar: some View {
        Button { ordered = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.appWarning).frame(width: 26, height: 26)
                    Circle().fill(Color.appAccent).frame(width: 26, height: 26).offset(x: 14)
                }
                .frame(width: 40, alignment: .leading)
                VStack(alignment: .leading, spacing: 1) {
                    Text(ordered ? "Ready" : "Check")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(appState.cartTotal)$")
                        .font(.digitalTimer(15))
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.tint(.appAccent), in: Circle())
            }
            .padding(10)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack {
                    Text("\(product.price)$")
                        .font(.digitalTimer(16))
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
