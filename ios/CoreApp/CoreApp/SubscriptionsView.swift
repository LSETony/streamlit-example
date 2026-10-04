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
                        Text("Tap a card to flip it and see what's included.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appTextSecondary)
                        VStack(spacing: 18) {
                            ForEach(appState.subscriptionPlans) { plan in
                                let isCurrent = plan.name == appState.membershipPlanName
                                PlanFlipCard(
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
}

/// A subscription tier's card — front face shows just name/price/the
/// "core." mark and the pay button (matching the reference layout);
/// tapping the card (not the button) flips it 3D to a back face listing
/// what's actually included. Owns its own flip state so each of the 3
/// cards flips independently.
private struct PlanFlipCard: View {
    let plan: SubscriptionPlan
    let isCurrent: Bool
    let isLoading: Bool
    var onPay: () -> Void

    @State private var isFlipped = false
    private let cardHeight: CGFloat = 300

    var body: some View {
        ZStack {
            frontFace.opacity(isFlipped ? 0 : 1)
            backFace
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(height: cardHeight)
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.3)
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: isFlipped)
        .onTapGesture { isFlipped.toggle() }
    }

    private var frontFace: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.brand(30))
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
                    Text("\(plan.price)$").font(.digitalTimer(24)).foregroundStyle(.white)
                    Text("/\(plan.period)").font(.brand(14)).foregroundStyle(Color.appTextSecondary)
                }
            }

            Spacer()

            HStack(alignment: .bottom) {
                Text("core.")
                    .font(.brand(26))
                    .foregroundStyle(.white)
                Spacer(minLength: 12)
                payButton
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(colors: [Color.appSurfaceElevated, Color.appSurface], startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
                .stroke(plan.recommended ? Color.appAccentPurple : .white.opacity(0.08), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 16, y: 10)
    }

    /// Sized to its own content (not a shared fixed width) so "pay 39$"
    /// and "pay 129$" both render on one line at the same height instead
    /// of one wrapping while the others don't — that's what made the 3
    /// cards look uneven next to each other.
    private var payButton: some View {
        Button(action: onPay) {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(isCurrent ? "current plan" : "pay \(plan.price)$ and switch")
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
        }
        .buttonStyle(.glassProminent)
        .tint(.appAccentPurple)
        .disabled(isCurrent || isLoading)
        .opacity(isCurrent ? 0.5 : 1)
    }

    private var backFace: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Details")
                .font(.brand(24))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(plan.perks, id: \.self) { perk in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.appAccent)
                        Text(perk).font(.brand(14)).foregroundStyle(Color.appTextSecondary)
                    }
                }
            }

            Spacer()

            HStack {
                Text("core.")
                    .font(.brand(18))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("tap to flip back")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 16, y: 10)
    }
}

#Preview {
    SubscriptionsView()
        .environmentObject(AppState())
}
