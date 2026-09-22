import SwiftUI

/// Opened by tapping the wallet icon on Home. Lets the member compare and
/// switch between the club's 3 subscription tiers.
struct SubscriptionsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var paymentService = PaymentService()
    @State private var payingPlanName: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Subscriptions")
                        .font(.brand(32))
                        .foregroundStyle(.white)

                    VStack(spacing: 14) {
                        ForEach(appState.subscriptionPlans) { plan in
                            planCard(plan)
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
            .modifier(PaymentSheetPresenter(paymentService: paymentService) { succeeded in
                if succeeded, let name = payingPlanName {
                    appState.membershipPlanName = name
                }
                payingPlanName = nil
            })
            .alert("Payment error", isPresented: Binding(get: { paymentService.errorMessage != nil }, set: { if !$0 { paymentService.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(paymentService.errorMessage ?? "")
            }
        }
    }

    private func planCard(_ plan: SubscriptionPlan) -> some View {
        let isCurrent = plan.name == appState.membershipPlanName
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.brand(20))
                        .foregroundStyle(.white)
                    if plan.recommended {
                        Text("RECOMMENDED")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.4)
                            .foregroundStyle(Color.appAccent)
                    }
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("$\(plan.price)").font(.digitalTimer(28)).foregroundStyle(.white)
                    Text("/\(plan.period)").font(.brand(14)).foregroundStyle(Color.appTextSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.perks, id: \.self) { perk in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.appAccent)
                        Text(perk).font(.brand(14)).foregroundStyle(Color.appTextSecondary)
                    }
                }
            }

            PrimaryButton(title: isCurrent ? "Current plan" : "Pay $\(plan.price) & switch", isEnabled: !isCurrent, color: .appAccentPurple) {
                payingPlanName = plan.name
                Task { await paymentService.startPayment(amountDollars: plan.price, description: "\(plan.name) subscription") }
            }
        }
        .padding(20)
        .background(plan.recommended ? Color.appAccentPurple.opacity(0.18) : Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
                .stroke(plan.recommended ? Color.appAccentPurple : Color.appDivider, lineWidth: plan.recommended ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }
}

#Preview {
    SubscriptionsView()
        .environmentObject(AppState())
}
