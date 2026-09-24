import SwiftUI
import UIKit

/// Opened from Profile — the member's own invite code plus a share sheet,
/// backed by member_stats.referral_code (AppState+Growth.swift). Real
/// server-tracked code, not a cosmetic string: `ensureReferralCode()`
/// creates and persists it the first time this screen (or leaderboard)
/// needs one.
struct ReferralView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingShareSheet = false

    private var shareText: String {
        "Join me at core. — use my code \(appState.referralCode) when you sign up."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Invite a friend")
                            .font(.brand(32))
                            .foregroundStyle(.white)
                        Text("Share your code — every friend who joins with it counts toward both your streaks.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    VStack(spacing: 14) {
                        Text(appState.referralCode.isEmpty ? "···" : appState.referralCode)
                            .font(.digitalTimer(40))
                            .foregroundStyle(.white)
                        Text("Your referral code")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(Color.appAccentPurple.opacity(0.18))
                    .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous).stroke(Color.appAccentPurple, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))

                    PrimaryButton(title: "Share invite", color: .appAccentPurple) {
                        isShowingShareSheet = true
                    }
                    .disabled(appState.referralCode.isEmpty)
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
            .task { await appState.ensureReferralCode() }
            .sheet(isPresented: $isShowingShareSheet) {
                ShareSheet(items: [shareText])
            }
        }
    }
}

/// Bridges UIKit's share sheet into SwiftUI — no SwiftUI ShareLink
/// equivalent existed in this project yet, and ShareLink itself needs no
/// wrapper, but a plain string share (not tied to a specific view's
/// layout) is simplest via UIActivityViewController directly.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ReferralView()
        .environmentObject(AppState())
}
