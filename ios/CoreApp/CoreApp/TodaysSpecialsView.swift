import SwiftUI

/// Opened from Home's "Specials for today" card — real trainer slots for
/// today that nobody has booked yet, offered at a discount instead of
/// just going to waste. Backed by AppState.todaysSpecials, which is
/// computed live from the actual trainer roster/slots/bookedSessions, so
/// booking one here removes it from the list immediately.
struct TodaysSpecialsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var bookedSpecialIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Specials for today")
                            .font(.brand(32))
                            .foregroundStyle(.white)
                        Text("Unbooked trainer slots, discounted so they don't go to waste.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    if appState.todaysSpecials.isEmpty {
                        Text("No leftover slots right now — check back later today.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appTextSecondary)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(appState.todaysSpecials) { special in
                                specialRow(special)
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
        }
    }

    private func specialRow(_ special: AppState.TrainerSpecial) -> some View {
        let isBooked = bookedSpecialIDs.contains(special.id)
        return HStack(spacing: 14) {
            Image(special.trainer.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(special.trainer.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(special.trainer.specialty) · Today \(special.time)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(special.originalPrice)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
                    .strikethrough()
                Text("$\(special.discountedPrice)")
                    .font(.digitalTimer(18))
                    .foregroundStyle(Color.appAccent)
            }

            Button {
                appState.bookTrainerSpecial(special)
                bookedSpecialIDs.insert(special.id)
            } label: {
                Text(isBooked ? "✓" : "Book")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, isBooked ? 12 : 16)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
            .glassEffect(isBooked ? .regular.tint(.appSuccess) : .regular.tint(.appAccentPurple).interactive(), in: Capsule())
            .disabled(isBooked)
        }
        .padding(14)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                .stroke(Color.appAccent.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

#Preview {
    TodaysSpecialsView()
        .environmentObject(AppState())
}
