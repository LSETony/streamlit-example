import SwiftUI

struct TrainersView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTrainer: Trainer?
    @State private var search = ""
    @State private var favorites: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Personal Trainers")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                SearchToolRow(search: $search)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(appState.trainers) { trainer in
                        TrainerTile(
                            trainer: trainer,
                            isFavorite: Binding(
                                get: { favorites.contains(trainer.id) },
                                set: { on in on ? favorites.insert(trainer.id) : favorites.remove(trainer.id) }
                            )
                        ) {
                            selectedTrainer = trainer
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
        .sheet(item: $selectedTrainer) { trainer in
            NavigationStack { TrainerDetailView(trainer: trainer) }
        }
    }
}

/// Shared search field + sort/filter icon row used by Trainers, Supplements
/// and Food recipes in the latest Figma pass.
struct SearchToolRow: View {
    @Binding var search: String

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(Color.appTextSecondary)
                TextField("", text: $search, prompt: Text("search").foregroundStyle(Color.appTextSecondary))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.appSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.appDivider, lineWidth: 1))

            toolIcon("arrow.up.arrow.down")
            toolIcon("slider.horizontal.3")
        }
    }

    private func toolIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(Color.appSurface)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.appDivider, lineWidth: 1))
    }
}

private struct TrainerTile: View {
    let trainer: Trainer
    @Binding var isFavorite: Bool
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onOpen) {
                ZStack(alignment: .topTrailing) {
                    PhotoPlaceholder(style: .trainer, icon: "person.fill")
                    FavoriteButton(isFavorite: $isFavorite).padding(8)
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous).stroke(Color.appDivider, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Text(trainer.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text("Personal trainer")
                .font(.system(size: 12))
                .foregroundStyle(Color.appTextSecondary)
        }
    }
}

struct TrainerDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let trainer: Trainer
    @State private var selectedSlot: String = ""
    @State private var didBook = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    InitialsAvatar(initials: trainer.initials, color: .appTextPrimary, size: 76)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(trainer.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                        Text(trainer.specialty)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.appTextSecondary)
                        HStack(spacing: 10) {
                            Text(trainer.rating).font(.digitalTimer(16)).foregroundStyle(Color.appAccent)
                            Text("\(trainer.reviews) reviews · \(trainer.yearsExperience)")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                }

                HStack(spacing: 8) {
                    ForEach(trainer.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(Color.appAccentDim)
                            .clipShape(Capsule())
                    }
                }

                Text(trainer.bio)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appTextSecondary)
                    .lineSpacing(4)

                HStack(spacing: 10) {
                    statBlock(value: "\(trainer.clients)", label: "Clients")
                    statBlock(value: "\(trainer.sessions)", label: "Sessions")
                    statBlock(value: trainer.priceCompact, label: "Per hour")
                }

                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: "Next free slots · Tue 15")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ForEach(appState.trainerSlots, id: \.self) { slot in
                            let on = selectedSlot == slot
                            Text(slot)
                                .font(.digitalTimer(15))
                                .foregroundStyle(on ? .white : Color.appTextPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(on ? Color.appAccent : Color.appSurface)
                                .overlay(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous).stroke(on ? .clear : Color.appDivider, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                                .onTapGesture { selectedSlot = slot }
                        }
                    }
                }

                PrimaryButton(title: didBook ? "✓ Session requested" : "Book \(trainer.name.split(separator: " ").first.map(String.init) ?? trainer.name) · \(selectedSlot.isEmpty ? appState.trainerSlots.first ?? "" : selectedSlot)", isEnabled: !didBook) {
                    didBook = true
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
        .onAppear { selectedSlot = appState.trainerSlots.first ?? "" }
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.digitalTimer(20)).foregroundStyle(.white)
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.4).foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

#Preview {
    NavigationStack { TrainersView() }
        .environmentObject(AppState())
}
