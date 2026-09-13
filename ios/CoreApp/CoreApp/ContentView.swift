import SwiftUI

enum MainTab: CaseIterable {
    case home, plan, pass, body, me

    var title: String {
        switch self {
        case .home: return "Home"
        case .plan: return "Plan"
        case .pass: return "Pass"
        case .body: return "Body"
        case .me: return "Me"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .plan: return "calendar"
        case .pass: return "qrcode"
        case .body: return "chart.line.uptrend.xyaxis"
        case .me: return "person.fill"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .home: HomeView(selectedTab: $selectedTab)
                case .plan: PlanView()
                case .pass: QRPassView()
                case .body: DiagnosticsView()
                case .me: ProfileView()
                }
            }
            .padding(.bottom, 78)

            CoreTabBar(selectedTab: $selectedTab)
        }
        .background(Color.appBackground)
    }
}

/// Custom bottom tab bar with a raised, circular "Pass" button in the
/// center — matches the "HOME PLAN QR PASS BODY ME" bar in the design.
struct CoreTabBar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home, label: "HOME")
            tabButton(.plan, label: "PLAN")
            centerButton
            tabButton(.body, label: "BODY")
            tabButton(.me, label: "ME")
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .background(
            Color.appSurfaceElevated
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func tabButton(_ tab: MainTab, label: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .tracking(0.3)
                .foregroundStyle(selectedTab == tab ? Color.appAccent : Color.appTextSecondary)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var centerButton: some View {
        Button {
            selectedTab = .pass
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "qrcode")
                    .font(.system(size: 16, weight: .bold))
                Text("QR\nPASS")
                    .font(.system(size: 9, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineSpacing(0)
            }
            .foregroundStyle(.white)
            .frame(width: 64, height: 64)
            .background(Color.appAccent)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.appBackground, lineWidth: 4))
            .shadow(color: Color.appAccent.opacity(0.5), radius: 10, y: 4)
            .offset(y: -14)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
