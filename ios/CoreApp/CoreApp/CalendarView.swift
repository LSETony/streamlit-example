import SwiftUI

/// The Calendar tab — confirmed as a real tab by the source's nav bar
/// component, but no calendar screen frame was in the Figma file itself,
/// so this is a plain, honest month grid rather than a guess at content
/// that hasn't been designed yet.
struct CalendarView: View {
    private let calendar = Calendar.current
    private let today = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Calendar")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 14) {
                    Text(monthTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    weekdayHeader

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                        ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                            dayCell(day)
                        }
                    }
                }
                .appCard(padding: 20)
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: today).capitalized
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                Text(day)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthDays: [Int?] {
        guard let range = calendar.range(of: .day, in: .month, for: today),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))
        else { return [] }
        let weekday = (calendar.component(.weekday, from: firstOfMonth) + 5) % 7 // Monday-first offset
        return Array(repeating: nil, count: weekday) + range.map { $0 }
    }

    private func dayCell(_ day: Int?) -> some View {
        let isToday = day == calendar.component(.day, from: today)
        return ZStack {
            if isToday {
                Circle().fill(Color.appAccent)
            }
            if let day {
                Text("\(day)")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : Color.appTextPrimary)
            }
        }
        .frame(height: 34)
    }
}

#Preview {
    CalendarView()
        .environmentObject(AppState())
}
