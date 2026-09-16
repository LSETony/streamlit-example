import SwiftUI

private struct Trainer: Identifiable {
    let id = UUID()
    let name: String
    let role: String
}

/// Figma frame 102:384 "iPhone 16 & 17 Pro Max - 11" — reached via the Home "Trainers" tile.
struct PersonalTrainersView: View {
    @State private var query = ""

    private let trainers = [
        Trainer(name: "Arina Ivolga", role: "Personal trainer"),
        Trainer(name: "Mercede Moini", role: "Personal trainer"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenTitle(title: "Personal Trainers")
                SearchBarRow(text: $query)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(trainers) { trainer in
                        VStack(spacing: 10) {
                            ZStack {
                                Circle().fill(Theme.placeholder.opacity(0.3))
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 40, height: 40)

                            Spacer()
                            Text(trainer.name).font(Theme.Typeface.display(16, weight: .medium)).foregroundStyle(.white)
                            Text(trainer.role).font(Theme.Typeface.display(10)).foregroundStyle(Theme.muted)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 250)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                                .stroke(Color.white, lineWidth: 1)
                        )
                    }
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
}

#Preview {
    NavigationStack { PersonalTrainersView() }
}
