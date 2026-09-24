import SwiftUI

/// Opened from Profile — ranks every device that's ever checked in or
/// finished a workout, by total visits, pulled fresh from member_stats
/// (public-read — see AppState+Growth.swift/add_growth_features.sql) each
/// time this screen opens.
struct LeaderboardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Leaderboard")
                            .font(.brand(32))
                            .foregroundStyle(.white)
                        Text("Ranked by total visits, across every core. member.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    if isLoading {
                        ProgressView().tint(Color.appTextSecondary).frame(maxWidth: .infinity).padding(.top, 40)
                    } else if appState.leaderboard.isEmpty {
                        Text("No check-ins yet — be the first.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appTextSecondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(appState.leaderboard.enumerated()), id: \.element.id) { index, entry in
                                row(rank: index + 1, entry: entry)
                            }
                        }
                    }
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
            .task {
                await appState.refreshLeaderboard()
                isLoading = false
            }
        }
    }

    private func row(rank: Int, entry: LeaderboardEntry) -> some View {
        HStack(spacing: 14) {
            Text("\(rank)")
                .font(.digitalTimer(18))
                .foregroundStyle(rank <= 3 ? Color.appAccent : Color.appTextSecondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isMe ? "You" : entry.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                if entry.streakDays > 0 {
                    Text("\(entry.streakDays)-day streak")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            Spacer()
            Text("\(entry.totalVisits)")
                .font(.digitalTimer(18))
                .foregroundStyle(.white)
            Text("visits")
                .font(.system(size: 11))
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(14)
        .background(entry.isMe ? Color.appAccentDim : Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

#Preview {
    LeaderboardView()
        .environmentObject(AppState())
}
