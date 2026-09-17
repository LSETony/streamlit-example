import SwiftUI

/// The Calendar tab: a custom SwiftUI month calendar in the iOS Calendar
/// app's visual language (month header with prev/next, weekday row, day
/// grid with a dot under days that have a booking) — built natively in
/// SwiftUI rather than wrapping UICalendarView, whose internal layout
/// didn't reliably respect the width it was given. Below it: the selected
/// day's bookings and a running list of upcoming reminders, each
/// reschedulable or cancelable.
struct CalendarView: View {
    @EnvironmentObject var appState: AppState
    @State private var displayedMonth: Date = Date()
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

                VStack(spacing: 16) {
                    monthHeader
                    weekdayHeader
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                        ForEach(Array(monthDates.enumerated()), id: \.offset) { _, date in
                            if let date {
                                dayCell(date)
                            } else {
                                Color.clear.frame(height: 46)
                            }
                        }
                    }
                }
                .appCard(padding: 20)

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

    // MARK: Month grid

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(monthTitle)
                .font(.brand(18))
                .foregroundStyle(.white)
            Spacer()
            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"], id: \.self) { day in
                Text(day)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: displayedMonth).capitalized
    }

    private var monthDates: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count
        else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingBlanks = (firstWeekday + 5) % 7 // Monday-first offset
        let days: [Date?] = (0..<daysInMonth).map { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        return Array(repeating: nil, count: leadingBlanks) + days
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = newMonth
    }

    private func dayCell(_ date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let hasBooking = appState.bookedSessions.contains { calendar.isDate($0.date, inSameDayAs: date) }

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle().fill(Color.appAccent)
                    } else if isToday {
                        Circle().stroke(Color.appAccent, lineWidth: 1.5)
                    }
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 15, weight: isSelected || isToday ? .bold : .regular))
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)

                Circle()
                    .fill(hasBooking ? Color.appAccent : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
