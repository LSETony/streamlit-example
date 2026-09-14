import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showManageSheet = false
    @State private var showQR = false
    @State private var showDiagnostics = false
    @State private var showStore = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    qrPassRow
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
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showQR) { QRPassView() }
            .sheet(isPresented: $showDiagnostics) { NavigationStack { DiagnosticsView() } }
            .sheet(isPresented: $showStore) { NavigationStack { StoreView() } }
        }
        .sheet(isPresented: $showManageSheet) {
            ManageMembershipSheet()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text(appState.initials)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color.appSurfaceElevated)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.appDivider, lineWidth: 1))
            VStack(alignment: .leading, spacing: 5) {
                Text(appState.fullName).font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                Text("Member since \(appState.memberSince) · \(appState.totalVisits) visits")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
    }

    private var qrPassRow: some View {
        Button { showQR = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appAccentDim)
                    Image(systemName: "qrcode").font(.system(size: 22)).foregroundStyle(Color.appAccent)
                }
                .frame(width: 46, height: 46)
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
            .background(Color.appSurface)
            .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous).stroke(Color.appDivider, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var membershipCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("MEMBERSHIP")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.8))
            Text(appState.membershipPlanName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            HStack(alignment: .bottom) {
                Text("Renews \(appState.membershipRenewDate) · ₽\(appState.membershipMonthlyPrice)/mo")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button { showManageSheet = true } label: {
                    Text("MANAGE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
        }
        .padding(20)
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
        .appCard(padding: 18)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: "Settings").padding(.bottom, 6)
            ForEach(Array(appState.settingsRows.enumerated()), id: \.element.id) { index, row in
                AppDivider()
                Button {
                    switch row.destination {
                    case .diagnostics: showDiagnostics = true
                    case .store: showStore = true
                    case .none: break
                    }
                } label: {
                    SettingsRow(title: row.name, subtitle: row.subtitle)
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
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(.vertical, 15)
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
}
