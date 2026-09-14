import SwiftUI

struct BookingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                dateSection
                zoneSection
                startSection
                lengthSection
                summaryCard
                PrimaryButton(title: bookButtonLabel) {
                    appState.reserve()
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            EyebrowLabel(text: "Reserve")
            Text("Gym booking")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "1 · Date")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(appState.bookingDates, id: \.self) { day in
                        let on = appState.selectedBookingDate == day
                        VStack(spacing: 4) {
                            Text(dow(for: day))
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.4)
                                .foregroundStyle(on ? .white.opacity(0.75) : Color.appTextSecondary)
                            Text("\(day)")
                                .font(.digitalTimer(20))
                                .foregroundStyle(on ? .white : Color.appTextPrimary)
                        }
                        .frame(width: 54)
                        .padding(.vertical, 10)
                        .background(on ? Color.appAccent : Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                                .stroke(on ? Color.appAccent : Color.appDivider, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                        .onTapGesture { appState.selectedBookingDate = day }
                    }
                }
            }
        }
    }

    private func dow(for day: Int) -> String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return names[(day + 6) % 7]
    }

    private var zoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "2 · Zone")
            VStack(spacing: 8) {
                ForEach(appState.zones) { zone in
                    ZoneRow(zone: zone, isSelected: appState.selectedZoneName == zone.name) {
                        appState.selectedZoneName = zone.name
                    }
                }
            }
        }
    }

    private var startSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "3 · Start")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(appState.bookingStartTimes, id: \.self) { time in
                    let on = appState.selectedBookingTime == time
                    Text(time)
                        .font(.digitalTimer(15))
                        .foregroundStyle(on ? .white : Color.appTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(on ? Color.appAccent : Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                                .stroke(on ? Color.appAccent : Color.appDivider, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                        .onTapGesture { appState.selectedBookingTime = time }
                }
            }
        }
    }

    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "4 · Length")
            HStack(spacing: 4) {
                ForEach(appState.bookingDurations, id: \.self) { minutes in
                    let on = appState.selectedBookingDuration == minutes
                    Text("\(minutes) min")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(on ? .white : Color.appTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(on ? Color.appAccent : Color.clear)
                        .clipShape(Capsule())
                        .onTapGesture { appState.selectedBookingDuration = minutes }
                }
            }
            .padding(4)
            .background(Color.appSurface)
            .clipShape(Capsule())
        }
    }

    private var endTimeLabel: String {
        let parts = appState.selectedBookingTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return appState.selectedBookingTime }
        let totalStart = parts[0] * 60 + parts[1]
        let totalEnd = totalStart + appState.selectedBookingDuration
        return String(format: "%02d:%02d", (totalEnd / 60) % 24, totalEnd % 60)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            summaryRow(label: "Zone", value: appState.selectedZoneName, color: .white)
            summaryRow(label: "When", value: "\(appState.selectedBookingDate) Sep · \(appState.selectedBookingTime)–\(endTimeLabel)", color: .white)
            summaryRow(label: "Forecast load", value: forecastLabel, color: .appAccent)
            AppDivider()
            Text("Unlimited membership allows 3 open bookings. You have \(appState.bookingsLeftThisWeek) left this week — cancel up to 2 hours before with no penalty.")
                .font(.system(size: 12))
                .foregroundStyle(Color.appTextSecondary)
        }
        .appCard(padding: 20)
    }

    private var forecastLabel: String {
        let load = appState.selectedZone?.occupancyPercent ?? 0
        let word = load > 80 ? "busy" : load > 55 ? "moderate" : "quiet"
        return "\(load)% · \(word)"
    }

    private func summaryRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundStyle(Color.appTextSecondary)
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
        }
    }

    private var bookButtonLabel: String {
        appState.isBooked ? "✓ Reserved · added to calendar" : "Reserve \(appState.selectedZoneName)"
    }
}

private struct ZoneRow: View {
    let zone: Zone
    let isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(zone.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(zone.freeSpots) of \(zone.capacity) spots free now")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appTextSecondary)
                    ProgressBarView(value: Double(zone.occupancyPercent) / 100, color: zone.statusColor, height: 4)
                        .padding(.top, 6)
                }
                Text("\(zone.occupancyPercent)%")
                    .font(.digitalTimer(18))
                    .foregroundStyle(zone.statusColor)
            }
            .padding(14)
            .background(isSelected ? Color.appAccentDim : Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                    .stroke(isSelected ? Color.appAccent : Color.appDivider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { BookingView() }
        .environmentObject(AppState())
}
