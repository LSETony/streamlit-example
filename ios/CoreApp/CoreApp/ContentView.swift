import SwiftUI

enum MainTab: CaseIterable {
    case home, plan, quickAdd, progress, me

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .plan: return "calendar"
        case .quickAdd: return "plus"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .me: return "person.fill"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .home
    @State private var showQuickAdd = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .home: HomeView(selectedTab: $selectedTab)
                case .plan: PlanView()
                case .quickAdd: HomeView(selectedTab: $selectedTab)
                case .progress: TrainingProgressView(selectedTab: $selectedTab)
                case .me: ProfileView()
                }
            }
            .padding(.bottom, 78)

            CoreTabBar(selectedTab: $selectedTab, showQuickAdd: $showQuickAdd)
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showQuickAdd) {
            QuickActionsSheet()
                .presentationDetents([.height(320)])
        }
    }
}

/// Custom bottom tab bar: icon-only, with a raised purple "+" quick-action
/// button in the center — matches the redesigned Home/Progress bar.
struct CoreTabBar: View {
    @Binding var selectedTab: MainTab
    @Binding var showQuickAdd: Bool

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            tabButton(.plan)
            centerButton
            tabButton(.progress)
            tabButton(.me)
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

    private func tabButton(_ tab: MainTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(selectedTab == tab ? Color.appPurple : Color.appTextSecondary)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var centerButton: some View {
        Button {
            showQuickAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color.appPurple)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.appBackground, lineWidth: 4))
                .shadow(color: Color.appPurple.opacity(0.5), radius: 10, y: 4)
                .offset(y: -14)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

/// Sheet presented from the "+" tab button — quick shortcuts into the
/// features that used to hang off a dedicated tab.
private struct QuickActionsSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var destination: QuickDestination?

    private enum QuickDestination: String, Identifiable {
        case workout, booking, scanner, nutrition
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 10) {
            Capsule().fill(Color.white.opacity(0.2)).frame(width: 40, height: 4).padding(.top, 8)
            Text("Quick actions").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).padding(.top, 6)

            quickRow(icon: "figure.strengthtraining.traditional", title: "Continue workout") { destination = .workout }
            quickRow(icon: "square.grid.2x2.fill", title: "Book a zone") { destination = .booking }
            quickRow(icon: "camera.viewfinder", title: "Scan a label") { destination = .scanner }
            quickRow(icon: "fork.knife", title: "Log a meal") { destination = .nutrition }
            Spacer(minLength: 0)
        }
        .screenPadding()
        .background(Color.appBackground.ignoresSafeArea())
        .sheet(item: $destination) { dest in
            NavigationStack {
                switch dest {
                case .workout: WorkoutSessionView()
                case .booking: BookingView()
                case .scanner: ScannerView()
                case .nutrition: NutritionView()
                }
            }
        }
    }

    private func quickRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.appPurpleDim)
                    Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Color.appPurple)
                }
                .frame(width: 40, height: 40)
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Color.appTextTertiary)
            }
            .padding(14)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
