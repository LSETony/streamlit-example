import SwiftUI

/// Opened from Workouts' "Gym Safety" card — a real rules and equipment
/// guide instead of an inert card.
struct GymSafetyView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Section: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let rules: [String]
    }

    private let sections: [Section] = [
        Section(icon: "dumbbell.fill", title: "Equipment Rules", rules: [
            "Re-rack weights and plates after every set.",
            "Wipe down benches and machines after use.",
            "Ask before working in on shared equipment.",
            "Never drop weights — lower them under control.",
        ]),
        Section(icon: "figure.strengthtraining.traditional", title: "Personal Safety", rules: [
            "Warm up for at least 5–10 minutes before lifting.",
            "Use a spotter for heavy bench, squat, or overhead work.",
            "Wear closed-toe athletic shoes on the gym floor.",
            "Stay hydrated — water stations are on every floor.",
        ]),
        Section(icon: "person.2.fill", title: "Facility Etiquette", rules: [
            "Share machines during peak hours — work in sets.",
            "Keep phone calls off the training floor.",
            "No filming other members without their consent.",
            "Return dumbbells and accessories to their racks.",
        ]),
        Section(icon: "cross.case.fill", title: "Emergency Procedures", rules: [
            "First aid kits and the AED are at reception.",
            "Alert any staff member immediately in an emergency.",
            "Emergency exits are marked at both ends of the floor.",
            "For anything life-threatening, call 911, then notify staff.",
        ]),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Gym Safety")
                            .font(.brand(32))
                            .foregroundStyle(.white)
                        Text("Rules and equipment guide for using the club safely.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Image(systemName: section.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.appAccentPurple)
                                    .clipShape(Circle())
                                Text(section.title)
                                    .font(.brand(18))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(section.rules, id: \.self) { rule in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color.appAccent)
                                            .padding(.top, 2)
                                        Text(rule)
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.appTextSecondary)
                                    }
                                }
                            }
                        }
                        .appCard(padding: 18)
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
}

#Preview {
    GymSafetyView()
}
