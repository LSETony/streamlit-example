import SwiftUI

/// Matches the Profile frame in the Figma source: header with avatar +
/// visit badge, QR access pass row, membership card, stats row, Apple
/// Health toggle, and a Logout button. Two additions beyond the static
/// frame: the QR row shows the member's own QR pass to be scanned at the
/// turnstile, and the membership card opens a sheet showing exactly when
/// the plan is valid until.
struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @State private var isShowingQRPass = false
    @State private var isShowingMembership = false
    @State private var isShowingReferral = false
    @State private var isShowingLeaderboard = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Profile")
                        .font(.brand(32))
                        .foregroundStyle(.white)
                    header
                    Button { isShowingQRPass = true } label: { qrPassRow }
                        .buttonStyle(.plain)
                    Button { isShowingMembership = true } label: { membershipCard }
                        .buttonStyle(.plain)
                    statsRow
                    healthCard
                    communityRow
                    Spacer(minLength: 40)
                    logoutButton
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingQRPass) {
                QRPassView()
            }
            .sheet(isPresented: $isShowingMembership) {
                MembershipDetailView()
            }
            .sheet(isPresented: $isShowingReferral) {
                ReferralView()
            }
            .sheet(isPresented: $isShowingLeaderboard) {
                LeaderboardView()
            }
        }
    }

    private var communityRow: some View {
        HStack(spacing: 10) {
            Button { isShowingReferral = true } label: {
                communityTile(icon: "person.badge.plus", title: "Invite a friend")
            }
            .buttonStyle(.plain)
            Button { isShowingLeaderboard = true } label: {
                communityTile(icon: "trophy.fill", title: "Leaderboard")
            }
            .buttonStyle(.plain)
        }
    }

    private func communityTile(icon: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.appAccent)
            Text(title)
                .font(.brand(15))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image("ProfileAvatar")
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.appDivider, lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(appState.fullName).font(.brand(18)).foregroundStyle(.white)
                Text("Member since \(appState.memberSince)")
                    .font(.brand(10))
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Text("\(appState.totalVisits) visits")
                .font(.brand(13))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.appAccent)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 0.5))
    }

    private var qrPassRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("QR access pass").font(.brand(24)).foregroundStyle(.white)
                Text("Turnstile and reception check-in")
                    .font(.brand(16))
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Image("IconChevronRight").customIcon(size: 14).foregroundStyle(Color.appTextSecondary)
        }
        .padding(18)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    private var membershipCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text("Membership")
                    .font(.brand(20))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Image("IconChevronRight").customIcon(size: 13).foregroundStyle(.white.opacity(0.7))
            }
            Text(appState.membershipPlanName)
                .font(.digitalTimer(32))
                .foregroundStyle(.white)
            Text("renews \(appState.membershipRenewDate.lowercased())")
                .font(.brand(16))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appAccentPurple)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            plainStat(value: "\(appState.septemberVisits)", label: "visits")
            plainStat(value: "\(appState.scansThisMonth)", label: "scans")
            plainStat(value: "\(appState.ptSessionsLeft)", label: "pt left")
        }
    }

    private func plainStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.digitalTimer(32)).foregroundStyle(.white)
            Text(label).font(.brand(24)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous).stroke(.white.opacity(0.5), lineWidth: 0.5))
    }

    private var healthToggleBinding: Binding<Bool> {
        Binding(
            get: { appState.appleHealthSyncEnabled },
            set: { newValue in
                guard newValue else {
                    appState.appleHealthSyncEnabled = false
                    return
                }
                Task {
                    let granted = await HealthKitService.shared.requestAuthorization()
                    await MainActor.run {
                        appState.appleHealthSyncEnabled = granted
                        if !granted {
                            appState.notificationCenter.trigger(
                                icon: "exclamationmark.triangle.fill", title: "Apple Health not connected",
                                subtitle: "Allow access in Settings to sync workouts.", accent: .appWarning
                            )
                        }
                    }
                }
            }
        )
    }

    private var healthCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Apple Health").font(.brand(24)).foregroundStyle(.white)
                Text(appState.appleHealthSyncEnabled ? "Workouts syncing to Health" : "Disconnected")
                    .font(.brand(16)).foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Toggle("", isOn: healthToggleBinding)
                .labelsHidden()
                .tint(.appAccent)
        }
        .padding(18)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    private var logoutButton: some View {
        PrimaryButton(title: "Logout", color: .appAccentPurple) {
            authService.signOut()
        }
        .padding(.top, 20)
    }
}

/// Opened by tapping the Profile membership card — surfaces exactly when
/// the current plan is valid until, plus what it includes.
private struct MembershipDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var matchingPlan: SubscriptionPlan? {
        appState.subscriptionPlans.first { $0.name == appState.membershipPlanName }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Membership")
                            .font(.brand(20))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(appState.membershipPlanName)
                            .font(.digitalTimer(32))
                            .foregroundStyle(.white)
                        if let plan = matchingPlan {
                            Text("$\(plan.price)/\(plan.period)")
                                .font(.brand(16))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appAccentPurple)
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        EyebrowLabel(text: "Active until")
                        Text(appState.membershipRenewDate)
                            .font(.digitalTimer(28))
                            .foregroundStyle(.white)
                        Text("Your membership auto-renews on this date unless cancelled.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))

                    if let plan = matchingPlan {
                        VStack(alignment: .leading, spacing: 10) {
                            EyebrowLabel(text: "Included")
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(plan.perks, id: \.self) { perk in
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.appAccent)
                                        Text(perk).font(.brand(14)).foregroundStyle(Color.appTextSecondary)
                                    }
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
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(AuthService())
}
