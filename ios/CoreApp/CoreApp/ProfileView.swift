import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @State private var showManageSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    membershipCard
                    statsRow
                    healthCard
                    settingsSection
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showManageSheet) {
            ManageMembershipSheet()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            InitialsAvatar(initials: appState.userName.prefix(2).uppercased(), size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.userName).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                Text("Member since Mar 2023").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
        }
    }

    private var membershipCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Renews \(appState.membershipRenewDate) · ₽\(appState.membershipMonthlyPrice)/mo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
            Button { showManageSheet = true } label: {
                Text("MANAGE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.appAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.appAccent)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(appState.septemberVisits)", label: "Sep visits")
            StatTile(value: "\(appState.scansThisMonth)", label: "Scans")
            StatTile(value: "\(appState.ptSessionsLeft)", label: "PT left")
        }
    }

    private var healthCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Health").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text("Steps, sleep, heart rate syncing").font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Toggle("", isOn: $appState.appleHealthSyncEnabled)
                .labelsHidden()
                .tint(.appAccent)
        }
        .appCard()
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: "Settings").padding(.bottom, 10)
            SettingsRow(title: "Notifications", subtitle: "Class reminders, protocol nudges, restock")
            AppDivider()
            SettingsRow(title: "Payments", subtitle: "Card · 4417 · invoices")
            AppDivider()
            NavigationLink {
                DiagnosticsView()
            } label: {
                SettingsRow(title: "Diagnostics history", subtitle: "6 reports since Mar 2023")
            }
            .buttonStyle(.plain)
            AppDivider()
            SettingsRow(title: "Monthly box", subtitle: "Ships 28 Sep")
            if requiresSignIn {
                AppDivider()
                Button {
                    authService.signOut()
                } label: {
                    Text("Sign out")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SettingsRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appTextTertiary)
        }
        .padding(.vertical, 14)
    }
}

private struct ManageMembershipSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Membership").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            Text("Renews \(appState.membershipRenewDate) at ₽\(appState.membershipMonthlyPrice)/month. Cancel anytime from here — you'll keep access until the renewal date.")
                .font(.system(size: 14))
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
            PrimaryButton(title: "Close") { dismiss() }
        }
        .padding(24)
        .background(Color.appBackground.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(AuthService())
}
