import SwiftUI

enum MainTab: CaseIterable, Hashable {
    case home, calendar, workouts, progress, me
}

/// Uses SwiftUI's native `TabView` / `Tab` (not a hand-built bar) so the
/// bottom bar is the real system control — on iOS 26 that's the floating
/// Liquid Glass tab bar Apple's own apps use, automatically, with no
/// approximation.
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: MainTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: MainTab.home) {
                HomeView()
            } label: {
                Label {
                    Text("Home")
                } icon: {
                    Image("IconHouse").renderingMode(.template)
                }
            }

            Tab(value: MainTab.calendar) {
                CalendarView()
            } label: {
                Label {
                    Text("Calendar")
                } icon: {
                    Image("IconCalendar").renderingMode(.template)
                }
            }

            Tab(value: MainTab.workouts) {
                WorkoutsView()
            } label: {
                Label {
                    Text("Workouts")
                } icon: {
                    Image("IconTrophy").renderingMode(.template)
                }
            }

            Tab(value: MainTab.progress) {
                ProgressTabView()
            } label: {
                Label {
                    Text("Progress")
                } icon: {
                    Image("IconTrending").renderingMode(.template)
                }
            }

            Tab(value: MainTab.me) {
                ProfileView()
            } label: {
                Label {
                    Text("Profile")
                } icon: {
                    Image("IconPerson").renderingMode(.template)
                }
            }
        }
        .tint(Color.appAccent)
        .background(Color.appBackground)
        .task {
            await appState.loadFromSupabase()
        }
        .alert(
            "Supabase error",
            isPresented: Binding(
                get: { appState.supabaseDebugMessage != nil },
                set: { if !$0 { appState.supabaseDebugMessage = nil } }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(appState.supabaseDebugMessage ?? "")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
