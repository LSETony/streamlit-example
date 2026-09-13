import SwiftUI

struct BookingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var reservedAlertZone: Zone?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("2 · ZONE")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.appTextSecondary)
                    Text("Book a zone")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }

                ForEach(appState.zones) { zone in
                    ZoneRow(zone: zone) {
                        appState.reserve(zone)
                        reservedAlertZone = zone
                    }
                }
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Booking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(Color.appAccent)
            }
        }
        .alert("Spot reserved", isPresented: Binding(get: { reservedAlertZone != nil }, set: { if !$0 { reservedAlertZone = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let zone = reservedAlertZone {
                Text("You're booked into \(zone.name) today.")
            }
        }
    }
}

private struct ZoneRow: View {
    let zone: Zone
    var onReserve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                HStack(spacing: 10) {
                    Image(systemName: zone.icon)
                        .foregroundStyle(Color.appAccent)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(zone.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(zone.freeSpots) of \(zone.capacity) spots free now")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
                Spacer()
                Text("\(zone.occupancyPercent)%")
                    .font(.brand(22))
                    .foregroundStyle(zone.statusColor)
            }
            ProgressBarView(value: Double(zone.occupancyPercent) / 100, color: zone.statusColor)
            Button(action: onReserve) {
                Text("Reserve")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.appAccent)
            }
            .buttonStyle(.plain)
            .disabled(zone.freeSpots == 0)
            .opacity(zone.freeSpots == 0 ? 0.4 : 1)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
                        .stroke(zone.occupancyPercent < 45 ? Color.appAccent.opacity(0.6) : .clear, lineWidth: 1.5)
                )
        )
    }
}

#Preview {
    NavigationStack { BookingView() }
        .environmentObject(AppState())
}
