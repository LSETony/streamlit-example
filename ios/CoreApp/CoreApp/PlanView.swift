import SwiftUI

struct PlanView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDay: Int = 15
    @State private var showWorkout = false

    private let monthDays = Array(1...30)
    private let today = 15
    private let dotDays: [Int: [EventKind]] = [
        16: [.trainer], 17: [.reservation], 18: [.workout],
        22: [.workout], 25: [.trainer],
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    calendarGrid
                    legend
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowLabel(text: "15 September")
                        ForEach(appState.events) { event in
                            EventRow(event: event) {
                                if event.kind == .workout { showWorkout = true }
                            }
                        }
                    }
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showWorkout) {
                WorkoutSessionView()
            }
        }
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 14) {
            ForEach(monthDays, id: \.self) { day in
                VStack(spacing: 4) {
                    Text("\(day)")
                        .font(.system(size: 15, weight: day == selectedDay ? .bold : .regular))
                        .foregroundStyle(day == selectedDay ? Color.white : Color.appTextPrimary)
                        .frame(width: 32, height: 32)
                        .background(day == selectedDay ? Color.appAccent : Color.clear)
                        .clipShape(Circle())
                    if let kinds = dotDays[day] {
                        HStack(spacing: 2) {
                            ForEach(kinds.indices, id: \.self) { i in
                                Circle().fill(kinds[i].color).frame(width: 4, height: 4)
                            }
                        }
                    } else {
                        Circle().fill(Color.clear).frame(width: 4, height: 4)
                    }
                }
                .onTapGesture { selectedDay = day }
            }
        }
        .appCard()
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .appAccent, label: "Workout")
            legendItem(color: .appSuccess, label: "Trainer")
            legendItem(color: .white, label: "Reservation")
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.appTextSecondary)
        }
    }
}

private struct EventRow: View {
    let event: ScheduleEvent
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                Rectangle()
                    .fill(event.kind.color)
                    .frame(width: 3)
                    .clipShape(Capsule())
                Text(event.time)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(event.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                StatusBadge(text: event.status.rawValue, color: event.status.color)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PlanView()
        .environmentObject(AppState())
}
