import SwiftUI
import UIKit

/// Opened as a sheet by tapping the Home hero photo — same presentation
/// mechanism as Trainers (a draggable sheet, not a full-screen cover).
/// Layout matches the reference: a photo strip up top, then title/address,
/// quick-action chips, a description card, and a primary action button.
/// Only one real gym-interior photo exists in the source assets — the rest
/// of the strip uses PhotoPlaceholder (same stand-in Food recipes uses for
/// missing photography) until real additional shots are added as assets.
struct GymPhotoViewer: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Image("HomeHero")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 220, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                        ForEach(["dumbbell.fill", "figure.strengthtraining.traditional"], id: \.self) { icon in
                            PhotoPlaceholder(icon: icon)
                                .frame(width: 220, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.clubName)
                        .font(.brand(24))
                        .foregroundStyle(.white)
                    Text(appState.clubAddress)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appTextSecondary)
                }

                HStack(spacing: 10) {
                    infoChipLabel(icon: "clock.fill", text: appState.clubHoursLabel)
                    Button {
                        openInMaps()
                    } label: {
                        infoChipLabel(icon: "location.fill", text: "Route")
                    }
                    .buttonStyle(.plain)
                }

                Text(appState.clubDescription)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appTextSecondary)
                    .lineSpacing(4)
                    .appCard(padding: 16)

                PrimaryButton(title: "Get Directions", color: .appAccentPurple) {
                    openInMaps()
                }
            }
            .screenPadding()
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    private func infoChipLabel(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            Text(text).font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private func openInMaps() {
        let query = "\(appState.clubName) \(appState.clubAddress)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?q=\(query)") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    GymPhotoViewer()
        .environmentObject(AppState())
}
