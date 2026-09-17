import SwiftUI

/// Matches the Profile frame in the Figma source exactly: header with
/// avatar + visit badge, QR access pass row, membership card, stats row,
/// Apple Health toggle, and a Logout button. No settings list, no QR
/// scanner screen, no membership-management sheet — none of that exists in
/// the source, so none of it is here.
struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Profile")
                        .font(.brand(32))
                        .foregroundStyle(.white)
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
        }
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

    private var healthCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Apple Health").font(.brand(24)).foregroundStyle(.white)
                Text(appState.appleHealthSyncEnabled ? "Steps, sleep, heart rate syncing" : "Disconnected")
                    .font(.brand(16)).foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Toggle("", isOn: $appState.appleHealthSyncEnabled)
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

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(AuthService())
}
