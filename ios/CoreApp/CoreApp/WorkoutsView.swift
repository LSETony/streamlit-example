import SwiftUI

/// The Workouts Library screen — matches the Figma frame exactly: category
/// filter pills, "Beginner's Plan", "Top 10 workouts" and "Important"
/// sections. This is what the center tab-bar dumbbell button opens.
struct WorkoutsView: View {
    @EnvironmentObject var appState: AppState
    @State private var libraryFilter = "All"
    private let libraryFilters = ["All", "Strength", "Cardio"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 8) {
                        ForEach(libraryFilters, id: \.self) { filter in
                            let on = libraryFilter == filter
                            Text(filter)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(on ? .white : Color.appTextPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(on ? Color.appAccent : Color.clear)
                                .overlay(Capsule().stroke(on ? .clear : Color.appDivider, lineWidth: 1))
                                .clipShape(Capsule())
                                .onTapGesture { libraryFilter = filter }
                        }
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .glassCircleButton()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("Beginner's Plan")
                        HStack(spacing: 10) {
                            ForEach(appState.beginnerPlanCards) { card in WorkoutCardTile(card: card) }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("Top 10 workouts")
                        HStack(spacing: 10) {
                            ForEach(appState.topWorkoutCards) { card in WorkoutCardTile(card: card) }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("Important")
                        HStack(spacing: 10) {
                            ForEach(appState.importantCards) { card in
                                Text(card.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .bottomLeading)
                                    .padding(16)
                                    .background(Color.appAccentPurple)
                                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
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
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13))
            .foregroundStyle(Color.appTextSecondary)
    }
}

private struct WorkoutCardTile: View {
    let card: WorkoutCard

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PhotoPlaceholder(style: card.photoStyle, icon: "figure.run")
            LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .bottom, endPoint: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(card.duration).font(.system(size: 10)).foregroundStyle(Color.appAccent)
                    Text(card.level).font(.system(size: 10)).foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(12)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous).stroke(Color.appDivider, lineWidth: 1))
    }
}

#Preview {
    WorkoutsView()
        .environmentObject(AppState())
}
