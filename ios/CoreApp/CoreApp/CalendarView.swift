import SwiftUI
import UIKit

/// The Calendar tab: a real native `UICalendarView` — the same system
/// component Apple's own Calendar/Reminders apps use — with a dot on every
/// day that has a booked session. Below it: that day's bookings, and a
/// running list of upcoming reminders, each reschedulable or cancelable.
struct CalendarView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDateComponents: DateComponents? = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    @State private var sessionToReschedule: BookedSession?
    @State private var sessionToCancel: BookedSession?

    private var selectedDate: Date {
        selectedDateComponents.flatMap { Calendar.current.date(from: $0) } ?? Date()
    }

    private var decoratedDates: Set<DateComponents> {
        Set(appState.bookedSessions.map { Calendar.current.dateComponents([.year, .month, .day], from: $0.date) })
    }

    private var sessionsOnSelectedDay: [BookedSession] {
        appState.bookedSessions
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }

    private var upcomingSessions: [BookedSession] {
        appState.bookedSessions
            .filter { $0.date > Date() && !Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Calendar")
                    .font(.brand(32))
                    .foregroundStyle(.white)

                NativeCalendarView(selectedDate: $selectedDateComponents, decoratedDates: decoratedDates)
                    .frame(height: 360)
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

    private var dayHeaderText: String {
        Calendar.current.isDateInToday(selectedDate) ? "Today" : selectedDate.formatted(date: .abbreviated, time: .omitted)
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

/// Wraps `UICalendarView` — Apple's real system calendar component, not an
/// approximation — with a small dot decoration on every date in
/// `decoratedDates` and single-date tap selection.
private struct NativeCalendarView: UIViewRepresentable {
    @Binding var selectedDate: DateComponents?
    let decoratedDates: Set<DateComponents>

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = Calendar.current
        view.locale = Locale.current
        view.fontDesign = .rounded
        view.delegate = context.coordinator
        view.tintColor = UIColor(Color.appAccent)
        view.backgroundColor = .clear

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.setSelected(selectedDate, animateSelection: false)
        view.selectionBehavior = selection
        return view
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        uiView.reloadDecorations(forDateComponents: Array(decoratedDates), animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: NativeCalendarView
        init(_ parent: NativeCalendarView) { self.parent = parent }

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard parent.decoratedDates.contains(dateComponents) else { return nil }
            return .default(color: UIColor(Color.appAccent), size: .small)
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            parent.selectedDate = dateComponents
        }
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
