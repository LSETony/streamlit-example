import SwiftUI

enum MainTab: CaseIterable {
    case home, calendar, workouts, diagnostics, me
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .home: HomeView(selectedTab: $selectedTab)
                case .calendar: CalendarView()
                case .workouts: WorkoutsView()
                case .diagnostics: DiagnosticsView()
                case .me: ProfileView()
                }
            }
            .padding(.bottom, 78)

            CoreTabBar(selectedTab: $selectedTab)
        }
        .background(Color.appBackground)
    }
}

/// The bottom pill tab bar: Home, Calendar, a raised orange "Workouts"
/// button in the center, Diagnostics, and Me.
struct CoreTabBar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home, icon: "house.fill")
            tabButton(.calendar, icon: "calendar")
            centerButton
            tabButton(.diagnostics, icon: "waveform.path.ecg")
            tabButton(.me, icon: "person.fill")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Color.appSurface
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.appDivider, lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 34, y: 14)
        )
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
                .background(Color.appAccent)
                .clipShape(Circle())
                .shadow(color: Color.appAccent.opacity(0.4), radius: 12, y: 6)
                .offset(y: -20)
        }
        .buttonStyle(.plain)
        .frame(width: 66)
        .padding(.horizontal, 6)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
