import SwiftUI

/// A normal shopping-cart screen — list of added items, total, checkout —
/// pushed onto the Store's navigation stack right after a product is added,
/// replacing the old floating "Check" pill.
struct CartView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var paymentService = PaymentService()
    @State private var didCheckOut = false

    var body: some View {
        Group {
            if appState.cart.isEmpty {
                emptyState
            } else {
                cartContent
            }
        }
        .screenPadding()
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Cart")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(PaymentSheetPresenter(paymentService: paymentService) { succeeded in
            if succeeded {
                didCheckOut = true
                appState.clearCart()
            }
        })
        .alert("Payment error", isPresented: Binding(get: { paymentService.errorMessage != nil }, set: { if !$0 { paymentService.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(paymentService.errorMessage ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "cart")
                .font(.system(size: 40))
                .foregroundStyle(Color.appTextSecondary)
            Text("Your cart is empty")
                .font(.brand(18))
                .foregroundStyle(.white)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var cartContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(appState.cart) { line in
                        cartRow(line)
                    }
                }
            }

            VStack(spacing: 14) {
                HStack {
                    Text("Total")
                        .font(.brand(18))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(appState.cartTotal)$")
                        .font(.digitalTimer(24))
                        .foregroundStyle(.white)
                }
                PrimaryButton(title: didCheckOut ? "✓ Order placed" : "Pay $\(appState.cartTotal) & checkout", isEnabled: !didCheckOut) {
                    Task { await paymentService.startPayment(amountDollars: appState.cartTotal, description: "core. store order") }
                }
            }
        }
    }

    private func cartRow(_ line: CartLine) -> some View {
        HStack(spacing: 12) {
            Text(line.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Text("\(line.price)$")
                .font(.digitalTimer(16))
                .foregroundStyle(Color.appTextSecondary)
            Button {
                appState.removeFromCart(line)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.appTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

#Preview {
    NavigationStack { CartView() }
        .environmentObject(AppState())
}
