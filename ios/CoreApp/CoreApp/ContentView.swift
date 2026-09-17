import SwiftUI

enum MainTab: CaseIterable {
    case home, workouts, me
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .home: HomeView()
                case .workouts: WorkoutsView()
                case .me: ProfileView()
                }
            }
            .padding(.bottom, 78)

            CoreTabBar(selectedTab: $selectedTab)
        }
        .background(Color.appBackground)
    }
}

/// The bottom pill tab bar: Home, a raised orange "Workouts" button in the
/// center, and Me.
struct CoreTabBar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            HStack(spacing: 0) {
                tabButton(.home, icon: "house.fill")
                centerButton
                tabButton(.me, icon: "person.fill")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: Capsule())
            .shadow(color: .black.opacity(0.4), radius: 34, y: 14)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private func tabButton(_ tab: MainTab, icon: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(selectedTab == tab ? Color.appAccent : Color.appTextSecondary)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var centerButton: some View {
        Button {
            selectedTab = .workouts
        } label: {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(.appAccent).interactive(), in: Circle())
        .shadow(color: Color.appAccent.opacity(0.4), radius: 12, y: 6)
        .offset(y: -20)
        .frame(width: 66)
        .padding(.horizontal, 6)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
