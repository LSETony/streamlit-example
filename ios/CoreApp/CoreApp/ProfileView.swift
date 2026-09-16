import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @State private var showManageSheet = false
    @State private var showQR = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    qrPassRow
                    membershipCard
                    statsRow
                    healthCard
                    Spacer(minLength: 40)
                    logoutButton
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showQR) { QRPassView() }
        }
        .sheet(isPresented: $showManageSheet) {
            ManageMembershipSheet()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            PhotoPlaceholder(style: .trainer, icon: "person.fill")
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.appDivider, lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(appState.fullName).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                Text("Member since \(appState.memberSince)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Text("\(appState.totalVisits) visits")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.appAccent)
                .clipShape(Capsule())
        }
    }

    private var qrPassRow: some View {
        Button { showQR = true } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("QR access pass").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    Text(appState.isCheckedIn ? "Checked in · tap to check out" : "Turnstile and reception check-in")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(Color.appTextSecondary)
            }
            .padding(18)
            .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous).stroke(Color.appDivider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var membershipCard: some View {
        Button { showManageSheet = true } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text("Membership")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                }
                Text(appState.membershipPlanName)
                    .font(.digitalTimer(26))
                    .foregroundStyle(.white)
                Text("renews \(appState.membershipRenewDate.lowercased())")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appAccentPurple)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
        }
        .buttonStyle(.plain)
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
            Text(value).font(.digitalTimer(24)).foregroundStyle(.white)
            Text(label).font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous).stroke(Color.appDivider, lineWidth: 1))
    }

    private var healthCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Apple Health").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(appState.appleHealthSyncEnabled ? "Steps, sleep, heart rate syncing" : "Disconnected")
                    .font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Toggle("", isOn: $appState.appleHealthSyncEnabled)
                .labelsHidden()
                .tint(.appAccent)
        }
        .padding(.vertical, 6)
    }

    private var logoutButton: some View {
        PrimaryButton(title: "Logout", color: .appAccentPurple) {
            authService.signOut()
        }
        .padding(.top, 20)
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
