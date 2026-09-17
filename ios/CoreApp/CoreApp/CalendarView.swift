import SwiftUI

/// The Calendar tab: Apple's own graphical month calendar (SwiftUI's
/// built-in `DatePicker(.graphical)` — the exact widget the system
/// Calendar/Reminders apps use to pick a date) rather than a hand-rolled
/// grid or a UICalendarView wrapper. Both of those fought SwiftUI's width
/// negotiation; DatePicker is native SwiftUI, so it always sizes correctly.
/// Below it: the selected day's bookings and a running list of upcoming
/// reminders, each reschedulable or cancelable.
struct CalendarView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDate: Date = Date()
    @State private var sessionToReschedule: BookedSession?
    @State private var sessionToCancel: BookedSession?

    private let calendar = Calendar.current

    private var sessionsOnSelectedDay: [BookedSession] {
        appState.bookedSessions
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }

    private var upcomingSessions: [BookedSession] {
        appState.bookedSessions
            .filter { $0.date > Date() && !calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Calendar")
                    .font(.brand(32))
                    .foregroundStyle(.white)

                DatePicker(
                    "Selected date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .tint(Color.appAccent)
                .colorScheme(.dark)
                .appCard(padding: 8)

                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: dayHeaderText)
                    if sessionsOnSelectedDay.isEmpty {
                        Text("No bookings on this day")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(sessionsOnSelectedDay) { session in
                                bookingRow(session)
                            }
                        }
                    }
                }

                if !upcomingSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowLabel(text: "Upcoming reminders")
                        VStack(spacing: 10) {
                            ForEach(upcomingSessions) { session in
                                bookingRow(session)
                            }
                        }
                    }
                }
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .sheet(item: $sessionToReschedule) { session in
            RescheduleSheet(session: session) { newDate in
                appState.rescheduleSession(session, to: newDate)
            }
        }
        .alert(
            "Cancel booking?",
            isPresented: Binding(get: { sessionToCancel != nil }, set: { if !$0 { sessionToCancel = nil } })
        ) {
            Button("Keep booking", role: .cancel) {}
            Button("Cancel booking", role: .destructive) {
                if let session = sessionToCancel { appState.cancelSession(session) }
            }
        } message: {
            if let session = sessionToCancel {
                Text("\(session.title) on \(session.date.formatted(date: .abbreviated, time: .shortened))")
            }
        }
    }

    // MARK: Bookings

    private var dayHeaderText: String {
        calendar.isDateInToday(selectedDate) ? "Today" : selectedDate.formatted(date: .abbreviated, time: .omitted)
    }

    private func bookingRow(_ session: BookedSession) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text("\(session.trainerName) · \(session.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Menu {
                Button("Reschedule") { sessionToReschedule = session }
                Button("Cancel", role: .destructive) { sessionToCancel = session }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

/// Opened from a booking row's menu to move a session to a new date/time.
private struct RescheduleSheet: View {
    let session: BookedSession
    let onReschedule: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var newDate: Date

    init(session: BookedSession, onReschedule: @escaping (Date) -> Void) {
        self.session = session
        self.onReschedule = onReschedule
        _newDate = State(initialValue: session.date)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker("New date & time", selection: $newDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .tint(Color.appAccent)
                    .colorScheme(.dark)
                Spacer(minLength: 0)
                PrimaryButton(title: "Confirm reschedule", color: .appAccentPurple) {
                    onReschedule(newDate)
                    dismiss()
                }
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
        }
    }
}

#Preview {
    CalendarView()
        .environmentObject(AppState())
}
