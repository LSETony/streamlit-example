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
                VStack(alignment: .leading, spacing: 22) {
                    Text("Subscriptions")
                        .font(.brand(32))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 14) {
                        EyebrowLabel(text: "Change plan")
                        VStack(spacing: 18) {
                            ForEach(appState.subscriptionPlans) { plan in
                                let isCurrent = plan.name == appState.membershipPlanName
                                PlanCard(
                                    plan: plan,
                                    isCurrent: isCurrent,
                                    isLoading: paymentService.isStartingPayment && payingPlanName == plan.name
                                ) {
                                    payingPlanName = plan.name
                                    Task { await paymentService.startPayment(amountDollars: plan.price, description: "\(plan.name) subscription") }
                                }
                            }
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
                    appState.notificationCenter.trigger(icon: "checkmark.circle.fill", title: "Payment successful", subtitle: "\(name) subscription active", accent: .appSuccess)
                    if let renewDate = Self.renewDateFormatter.date(from: appState.membershipRenewDate) {
                        NotificationService.scheduleRenewalReminder(planName: name, renewDate: renewDate)
                    }
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

    private static let renewDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
}

/// A subscription tier's card — everything a member needs to decide (name,
/// price, every perk) is visible at once, no tap-to-reveal: a pricing
/// decision is exactly the moment you don't want to hide information
/// behind an interaction. The recommended plan gets a badge, a tinted
/// glass background and a soft glow so it reads as the suggested pick at
/// a glance.
private struct PlanCard: View {
    let plan: SubscriptionPlan
    let isCurrent: Bool
    let isLoading: Bool
    var onPay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if plan.recommended {
                Text("MOST POPULAR")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular.tint(.appAccentPurple), in: Capsule())
            }

            HStack(alignment: .firstTextBaseline) {
                Text(plan.name)
                    .font(.brand(24))
                    .foregroundStyle(.white)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("$\(plan.price)").font(.digitalTimer(30)).foregroundStyle(.white)
                    Text("/\(plan.period)").font(.brand(14)).foregroundStyle(Color.appTextSecondary)
                }
            }

            AppDivider()

            VStack(alignment: .leading, spacing: 12) {
                ForEach(plan.perks, id: \.self) { perk in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(plan.recommended ? Color.appAccentPurple : Color.appAccent)
                        Text(perk)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }

            PrimaryButton(
                title: isCurrent ? "Current plan" : "Pay $\(plan.price) & switch",
                isEnabled: !isCurrent,
                isLoading: isLoading,
                color: .appAccentPurple,
                action: onPay
            )
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            plan.recommended ? .regular.tint(.appAccentPurple.opacity(0.35)) : .regular,
            in: RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
                .stroke(plan.recommended ? Color.appAccentPurple : .white.opacity(0.08), lineWidth: plan.recommended ? 1.5 : 1)
        )
        .shadow(color: plan.recommended ? Color.appAccentPurple.opacity(0.3) : .black.opacity(0.25), radius: plan.recommended ? 22 : 12, y: 8)
        .scaleEffect(plan.recommended ? 1.02 : 1)
    }
}

#Preview {
    SubscriptionsView()
        .environmentObject(AppState())
}
