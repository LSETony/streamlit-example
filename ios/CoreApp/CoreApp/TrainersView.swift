import SwiftUI

struct TrainersView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTrainer: Trainer?
    @State private var selectedFilter = "All"

    private let filters = ["All", "Strength", "Rehab", "Nutrition"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                filterRow
                ForEach(appState.trainers) { trainer in
                    Button { selectedTrainer = trainer } label: {
                        TrainerRow(trainer: trainer)
                    }
                    .buttonStyle(.plain)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            EyebrowLabel(text: "14 specialists")
            Text("Trainers")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    let on = selectedFilter == filter
                    Text(filter)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(on ? .white : Color.appTextPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(on ? Color.appAccent : Color.appSurface)
                        .overlay(Capsule().stroke(on ? .clear : Color.appDivider, lineWidth: 1))
                        .clipShape(Capsule())
                        .onTapGesture { selectedFilter = filter }
                }
            }
        }
    }
}

private struct TrainerRow: View {
    let trainer: Trainer

    var body: some View {
        HStack(spacing: 14) {
            InitialsAvatar(initials: trainer.initials, color: .appTextPrimary, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(trainer.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(trainer.specialty)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
                HStack(spacing: 10) {
                    Text(trainer.rating)
                        .font(.digitalTimer(14))
                        .foregroundStyle(Color.appAccent)
                    Text("\(trainer.reviews) reviews")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appTextSecondary)
                    Text(trainer.priceLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appTextSecondary)
                }
                .padding(.top, 3)
            }
            Spacer()
            Text(trainer.nextAvailable.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(trainer.availabilityColor)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
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
