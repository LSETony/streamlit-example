import SwiftUI

/// Opened from Workouts' "Events" card — a real, RSVP-able events calendar
/// instead of an inert card, matching Gym Safety's treatment of "Rules".
struct EventsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var joinedEventIDs: Set<UUID> = []

    private struct ClubEvent: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let dateLabel: String
        let timeLabel: String
        let spotsLeft: Int
        let description: String
    }

    private let events: [ClubEvent] = [
        ClubEvent(
            icon: "flame.fill", title: "HIIT Circuit Night",
            dateLabel: "Fri, Oct 3", timeLabel: "19:00", spotsLeft: 6,
            description: "A 45-minute group HIIT session on the studio floor — bodyweight and kettlebell circuits, all levels welcome."
        ),
        ClubEvent(
            icon: "figure.strengthtraining.traditional", title: "Powerlifting Seminar",
            dateLabel: "Sat, Oct 11", timeLabel: "11:00", spotsLeft: 10,
            description: "Squat/bench/deadlift technique breakdown with the strength floor coaches, plus a form-check Q&A."
        ),
        ClubEvent(
            icon: "leaf.fill", title: "Mobility & Recovery Workshop",
            dateLabel: "Wed, Oct 15", timeLabel: "18:30", spotsLeft: 14,
            description: "Guided stretching, foam rolling and breathing work to help recovery between heavy training blocks."
        ),
        ClubEvent(
            icon: "person.3.fill", title: "Member Social + New Gear Reveal",
            dateLabel: "Sat, Oct 25", timeLabel: "17:00", spotsLeft: 30,
            description: "Meet other members, try the new equipment on the strength floor, light snacks and drinks provided."
        ),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Events")
                            .font(.brand(32))
                            .foregroundStyle(.white)
                        Text("What's on this month — tap Join to reserve a spot.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    VStack(spacing: 14) {
                        ForEach(events) { event in
                            eventCard(event)
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

    private func eventCard(_ event: ClubEvent) -> some View {
        let isJoined = joinedEventIDs.contains(event.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: event.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.appAccentPurple)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.brand(17))
                        .foregroundStyle(.white)
                    Text("\(event.dateLabel) · \(event.timeLabel)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                Spacer()
            }

            Text(event.description)
                .font(.system(size: 13))
                .foregroundStyle(Color.appTextSecondary)
                .lineSpacing(3)

            HStack {
                Text(isJoined ? "You're in!" : "\(event.spotsLeft) spots left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isJoined ? Color.appSuccess : Color.appTextSecondary)
                Spacer()
                Button {
                    if isJoined {
                        joinedEventIDs.remove(event.id)
                    } else {
                        joinedEventIDs.insert(event.id)
                    }
                } label: {
                    Text(isJoined ? "Joined ✓" : "Join")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .glassEffect(isJoined ? .regular.tint(.appSuccess) : .regular.tint(.appAccentPurple), in: Capsule())
            }
        }
        .appCard(padding: 16)
    }
}

#Preview {
    EventsView()
}
