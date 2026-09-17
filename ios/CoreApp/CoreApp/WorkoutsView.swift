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
                    Text("Workouts")
                        .font(.brand(32))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(libraryFilters, id: \.self) { filter in
                                    let on = libraryFilter == filter
                                    Text(filter)
                                        .font(.brand(16))
                                        .foregroundStyle(on ? .white : Color.appTextPrimary)
                                        .padding(.horizontal, 16)
                                        .frame(minWidth: 89, minHeight: 50)
                                        .background(on ? Color.appAccent : Color.appBackground.opacity(0.2))
                                        .clipShape(Capsule())
                                        .onTapGesture { libraryFilter = filter }
                                }
                            }
                        }
                        Spacer(minLength: 0)
                        Image("IconSearch").customIcon(size: 14)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .glassCircleButton()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("Beginner's Plan")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(appState.beginnerPlanCards) { card in WorkoutCardTile(card: card) }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("Top 10 workouts")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(appState.topWorkoutCards) { card in WorkoutCardTile(card: card) }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("Important")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(appState.importantCards) { card in
                                Text(card.title)
                                    .font(.brand(16))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .bottomLeading)
                                    .padding(16)
                                    .background(Color.appAccentPurple)
                                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.brand(20))
            .foregroundStyle(.white)
    }
}

private struct WorkoutCardTile: View {
    let card: WorkoutCard

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(card.imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .bottom, endPoint: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.brand(16))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(card.duration).font(.brand(10)).foregroundStyle(Color.appAccent)
                    Text(card.level).font(.brand(10)).foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(12)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }
}

#Preview {
    WorkoutsView()
        .environmentObject(AppState())
}
