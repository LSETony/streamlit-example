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

                    membershipCard

                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowLabel(text: "Change plan")
                        VStack(spacing: 14) {
                            ForEach(appState.subscriptionPlans) { plan in
                                planCard(plan)
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

    /// Masked "card number" look — the last group is real, derived from this
    /// device's stable DeviceUser.id (same id every other real-data write in
    /// the app keys off), not a random placeholder.
    private var cardNumberGroups: [String] {
        let hex = DeviceUser.id.replacingOccurrences(of: "-", with: "").uppercased()
        return ["••••", "••••", "••••", String(hex.suffix(4))]
    }

    // MARK: Membership card (a real "core." membership/bank card look)

    private var membershipCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("core.")
                    .font(.brand(24))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "wave.3.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer(minLength: 30)

            Text(appState.membershipPlanName.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 12) {
                ForEach(Array(cardNumberGroups.enumerated()), id: \.offset) { _, group in
                    Text(group)
                        .font(.digitalTimer(20))
                        .foregroundStyle(.white)
                }
            }
            .padding(.top, 6)

            Spacer(minLength: 20)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MEMBER SINCE")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(appState.memberSince)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("VALID THRU")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(appState.membershipRenewDate)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.bottom, 10)

            Text(appState.fullName.uppercased())
                .font(.brand(17))
                .foregroundStyle(.white)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 220)
        .glassEffect(.regular.tint(.appAccentPurple), in: RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
        .overlay(
            LinearGradient(
                colors: [Color.appAccentPurple.opacity(0.55), Color.appAccent.opacity(0.35), .clear],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
            .allowsHitTesting(false)
        )
        .overlay(
            LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
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
