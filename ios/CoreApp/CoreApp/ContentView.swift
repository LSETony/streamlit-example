import SwiftUI

enum MainTab: CaseIterable, Hashable {
    case home, calendar, workouts, progress, me
}

private extension MainTab {
    var label: String {
        switch self {
        case .home: return "Home"
        case .calendar: return "Calendar"
        case .workouts: return "Workouts"
        case .progress: return "Progress"
        case .me: return "Profile"
        }
    }
    var icon: String {
        switch self {
        case .home: return "IconHouse"
        case .calendar: return "IconCalendar"
        case .workouts: return "IconTrophy"
        case .progress: return "IconTrending"
        case .me: return "IconPerson"
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
                case .home: HomeView()
                case .calendar: CalendarView()
                case .workouts: WorkoutsView()
                case .progress: ProgressTabView()
                case .me: ProfileView()
                }
            }
            .padding(.bottom, 78)

            CoreTabBar(selectedTab: $selectedTab)
        }
        .background(Color.appBackground)
    }
}

/// The bottom pill tab bar — matches the source's "Component 36" exactly:
/// Home / Calendar / Workouts / Progress / Profile as five equal flat tabs
/// in one glass capsule, with a darker glass "chip" behind whichever tab is
/// selected (real Liquid Glass throughout, no plain-material approximation).
struct CoreTabBar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: Capsule())
            .shadow(color: .black.opacity(0.4), radius: 34, y: 14)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    private func tabButton(_ tab: MainTab) -> some View {
        let isSelected = selectedTab == tab
        let button = Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 6) {
                Image(tab.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                Text(tab.label)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(isSelected ? Color.appAccent : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)

        return Group {
            if isSelected {
                button.glassEffect(.regular.tint(.black.opacity(0.35)), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                button
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
