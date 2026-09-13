import SwiftUI

struct StoreView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                subscriptionCard

                EyebrowLabel(text: "Supplements")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(appState.products) { product in
                        ProductTile(product: product) {
                            appState.addToCart(product)
                        }
                    }
                }
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 90)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Store")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if appState.cartCount > 0 {
                HStack {
                    Text("\(appState.cartCount) item\(appState.cartCount == 1 ? "" : "s")")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text("₽\(appState.cartTotal) · Checkout")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.appAccent)
            }
        }
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("₽4 180").font(.brand(26)).foregroundStyle(.white)
                    }
                    Text("₽3 550 monthly · cancel anytime")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Button {
                    appState.isSubscribed.toggle()
                } label: {
                    Text(appState.isSubscribed ? "SUBSCRIBED" : "SUBSCRIBE")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.appAccent)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }
}

private struct ProductTile: View {
    let product: Product
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                    .fill(Color.appSurfaceElevated)
                Text(product.code)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .frame(height: 70)

            Text(product.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(minHeight: 34, alignment: .top)

            HStack {
                Text("₽\(product.price)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.appTextSecondary)
                    .strikethrough()
                Spacer()
                Button(action: onAdd) {
                    ZStack {
                        Circle().fill(Color.appAccent)
                        if product.inCart > 0 {
                            Text("\(product.inCart)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }
}

#Preview {
    NavigationStack { StoreView() }
        .environmentObject(AppState())
}
