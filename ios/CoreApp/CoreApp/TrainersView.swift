import SwiftUI

struct TrainersView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTrainer: Trainer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Trainers")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)

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
        .navigationTitle("Trainers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.foregroundStyle(.appAccent)
            }
        }
        .sheet(item: $selectedTrainer) { trainer in
            TrainerDetailSheet(trainer: trainer)
                .presentationDetents([.medium])
        }
    }
}

private struct TrainerRow: View {
    let trainer: Trainer

    var body: some View {
        HStack(spacing: 14) {
            InitialsAvatar(initials: trainer.initials, color: trainer.avatarColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(trainer.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text(trainer.specialty)
                    .font(.system(size: 13))
                    .foregroundStyle(.appTextSecondary)
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(.appAccent)
                        Text(String(format: "%.1f", trainer.rating)).font(.system(size: 13, weight: .semibold)).foregroundStyle(.appAccent)
                    }
                    Text("\(trainer.reviews) reviews")
                        .font(.system(size: 12))
                        .foregroundStyle(.appTextTertiary)
                    Text("₽\(trainer.pricePerHour)/h")
                        .font(.system(size: 12))
                        .foregroundStyle(.appTextTertiary)
                }
            }
            Spacer()
            Text(trainer.nextAvailable)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(trainer.isTodayAvailable ? .appSuccess : .appTextSecondary)
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }
}

private struct TrainerDetailSheet: View {
    let trainer: Trainer
    @Environment(\.dismiss) private var dismiss
    @State private var didBook = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                InitialsAvatar(initials: trainer.initials, color: trainer.avatarColor, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(trainer.name).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                    Text(trainer.specialty).font(.system(size: 14)).foregroundStyle(.appTextSecondary)
                }
                Spacer()
            }
            HStack(spacing: 24) {
                statBlock(value: String(format: "%.1f", trainer.rating), label: "Rating")
                statBlock(value: "\(trainer.reviews)", label: "Reviews")
                statBlock(value: "₽\(trainer.pricePerHour)", label: "Per hour")
            }
            Spacer()
            if didBook {
                Text("Session request sent — \(trainer.name) will confirm shortly.")
                    .font(.system(size: 14))
                    .foregroundStyle(.appSuccess)
            }
            PrimaryButton(title: didBook ? "Requested" : "Book a session", isEnabled: !didBook) {
                didBook = true
            }
        }
        .padding(24)
        .background(Color.appBackground.ignoresSafeArea())
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(label.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundStyle(.appTextSecondary)
        }
    }
}

#Preview {
    NavigationStack { TrainersView() }
        .environmentObject(AppState())
}
