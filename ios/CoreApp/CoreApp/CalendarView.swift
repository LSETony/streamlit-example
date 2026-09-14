import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDay: Int = 15
    @State private var showWorkout = false
    @State private var showBooking = false

    private let monthDays = Array(1...30)
    private let dotDays: [Int: [EventKind]] = [
        16: [.trainer], 17: [.reservation], 18: [.workout],
        22: [.workout], 25: [.trainer],
    ]
    private let weekdayHeaders = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
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
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showWorkout) {
                WorkoutSessionView()
            }
            .sheet(isPresented: $showBooking) {
                NavigationStack { BookingView() }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                EyebrowLabel(text: "September 2026")
                Text("Your calendar")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button { showBooking = true } label: {
                Text("+ BOOK")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.appAccent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(weekdayHeaders.indices, id: \.self) { i in
                    Text(weekdayHeaders[i])
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(Color.appTextSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(monthDays, id: \.self) { day in
                    VStack(spacing: 3) {
                        Text("\(day)")
                            .font(.digitalTimer(14))
                            .foregroundStyle(day == selectedDay ? .white : Color.appTextPrimary)
                        if let kinds = dotDays[day] {
                            Circle().fill(kinds[0].color).frame(width: 4, height: 4)
                        } else {
                            Circle().fill(Color.clear).frame(width: 4, height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(day == selectedDay ? Color.appAccent : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onTapGesture { selectedDay = day }
                }
            }
        }
        .appCard(padding: 16)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .appAccent, label: "Workout")
            legendItem(color: .appSuccess, label: "Trainer")
            legendItem(color: .appTextSecondary, label: "Reservation")
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11))
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
                    .font(.digitalTimer(16))
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
    CalendarView()
        .environmentObject(AppState())
}
