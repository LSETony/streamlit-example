import SwiftUI

private struct WorkoutItem: Identifiable {
    let id = UUID()
    let title: String
    let meta: String
    let level: String
}

/// Figma frame 95:133 "iPhone 16 & 17 Pro Max - 9" — reached via the Home "Book" tile.
struct WorkoutPlansView: View {
    @State private var filter = "All"
    private let filters = ["All", "Strength", "Cardio", "Yoga"]

    private let beginnerPlans = [
        WorkoutItem(title: "Beginner Female Aesthetics", meta: "7 day", level: "Beginner"),
        WorkoutItem(title: "Beginner Body Weight Plan", meta: "7 day", level: "Beginner"),
    ]
    private let topWorkouts = [
        WorkoutItem(title: "Sam's Prental Flow", meta: "22 mins", level: "Beginner"),
        WorkoutItem(title: "Chest and Triceps", meta: "22 mins", level: "Inter"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 10) {
                    ForEach(filters, id: \.self) { f in
                        Button { filter = f } label: {
                            Text(f)
                                .font(Theme.Typeface.display(16, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .frame(height: 40)
                                .background(
                                    filter == f ? Theme.orange : Color.black.opacity(0.2),
                                    in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }

                section(title: "Beginner's Plan", items: beginnerPlans)
                section(title: "Top 10 workouts", items: topWorkouts)

                HStack(spacing: 14) {
                    infoTile(title: "Gym Safety")
                    infoTile(title: "Events")
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 60)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private func section(title: String, items: [WorkoutItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(Theme.Typeface.display(20, weight: .semibold)).foregroundStyle(.white)
            HStack(spacing: 14) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Spacer()
                        Text(item.level)
                            .font(Theme.Typeface.display(10, weight: .semibold))
                            .foregroundStyle(Theme.orange)
                        Text(item.title)
                            .font(Theme.Typeface.display(16, weight: .medium))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.meta)
                            .font(Theme.Typeface.display(10))
                            .foregroundStyle(Theme.orange)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .bottomLeading)
                    .background(
                        LinearGradient(colors: [Theme.purple.opacity(0.6), Color.black.opacity(0.4)], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    )
                }
            }
        }
    }

    private func infoTile(title: String) -> some View {
        Text(title)
            .font(Theme.Typeface.display(16, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .bottomLeading)
            .padding(16)
            .background(Theme.purple, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

#Preview {
    NavigationStack { WorkoutPlansView() }
}
