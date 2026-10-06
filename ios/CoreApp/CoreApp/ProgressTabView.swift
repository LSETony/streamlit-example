import SwiftUI

/// The Progress tab — shares its entire body with ProgressDetailView (Home's
/// "Your Progress" sheet) via ProgressContentView, so there's one real,
/// Liquid-Glass-styled Progress screen instead of two screens that drift
/// apart. Previously had its own "Training progress %" card and a club
/// occupancy card — the former was a static @Published value nothing in
/// the app ever updated (not real data), and the latter belongs to the
/// club right now, not this member's own progress, and already has a home
/// on Home + OccupancyDetailView.
struct ProgressTabView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Progress")
                    .font(.brand(32))
                    .foregroundStyle(.white)
                ProgressContentView()
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}

#Preview {
    ProgressTabView()
        .environmentObject(AppState())
}
