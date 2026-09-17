import SwiftUI

/// The Workouts Library screen — matches the Figma frame exactly: category
/// filter pills, "Beginner's Plan", "Top 10 workouts" and "Important"
/// sections. This is what the center tab-bar dumbbell button opens.
///
/// Card widths are computed once from a single GeometryReader and passed
/// down as explicit CGFloat values instead of relying on flexible layout
/// (HStack/LazyVGrid .flexible() columns) — those repeatedly let an
/// oversized child report its own width back up and widen the whole
/// screen, so every card here gets a concrete, non-negotiable size.
struct WorkoutsView: View {
    @EnvironmentObject var appState: AppState
    @State private var libraryFilter = "All"
    private let libraryFilters: [(name: String, icon: String)] = [
        ("All", "square.grid.2x2.fill"),
        ("Strength", "dumbbell.fill"),
        ("Cardio", "figure.run"),
    ]

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let contentWidth = geo.size.width - AppMetrics.screenPadding * 2
                let cardWidth = (contentWidth - 10) / 2

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Workouts")
                            .font(.brand(32))
                            .foregroundStyle(.white)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(libraryFilters, id: \.name) { filter in
                                    let on = libraryFilter == filter.name
                                    VStack(spacing: 10) {
                                        Image(systemName: filter.icon)
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text(filter.name)
                                            .font(.brand(14))
                                            .foregroundStyle(.white)
                                    }
                                    .frame(width: 110, height: 100)
                                    .background(on ? Color.appAccent : Color.appBackground.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
                                    .scrollTransition { content, phase in
                                        content
                                            .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                            .opacity(phase.isIdentity ? 1 : 0.6)
                                    }
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            libraryFilter = filter.name
                                        }
                                    }
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)

                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Beginner's Plan")
                            HStack(spacing: 10) {
                                ForEach(appState.beginnerPlanCards) { card in
                                    WorkoutCardTile(card: card, width: cardWidth)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Top 10 workouts")
                            HStack(spacing: 10) {
                                ForEach(appState.topWorkoutCards) { card in
                                    WorkoutCardTile(card: card, width: cardWidth)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Important")
                            HStack(spacing: 10) {
                                ForEach(appState.importantCards) { card in
                                    ImportantCardTile(card: card, width: cardWidth)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppMetrics.screenPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
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
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(card.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: 200)
                .clipped()
            LinearGradient(colors: [.black.opacity(0.85), .black.opacity(0.35), .clear], startPoint: .bottom, endPoint: .top)
                .frame(width: width, height: 110)
                .frame(maxHeight: .infinity, alignment: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.brand(15))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(card.duration).font(.brand(10)).foregroundStyle(Color.appAccent)
                    Text(card.level).font(.brand(10)).foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(12)
            .frame(width: width, alignment: .leading)
        }
        .frame(width: width, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }
}

private struct ImportantCardTile: View {
    let card: ImportantCard
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: card.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.16))
                .clipShape(Circle())
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 3) {
                Text(card.title)
                    .font(.brand(16))
                    .foregroundStyle(.white)
                Text(card.subtitle)
                    .font(.brand(11))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(16)
        .frame(width: width, height: 200, alignment: .topLeading)
        .background(
            LinearGradient(colors: [Color.appAccentPurple.opacity(0.85), Color.appAccentPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }
}

#Preview {
    WorkoutsView()
        .environmentObject(AppState())
}
