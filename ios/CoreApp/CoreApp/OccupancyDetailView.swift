import SwiftUI

/// Opened by tapping the "Club Occupancy" card on Home. Shows the current
/// reading plus a fuller hour-by-hour breakdown of the day, and the
/// quietest/busiest times to help members plan a visit.
struct OccupancyDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var quietestHour: String {
        appState.occupancyHourly.min { $0.value < $1.value }?.hour ?? "--"
    }
    private var busiestHour: String {
        appState.occupancyHourly.max { $0.value < $1.value }?.hour ?? "--"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Club Occupancy")
                                .font(.brand(24))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        HStack(alignment: .bottom, spacing: 10) {
                            Text("\(appState.occupancyPercent)")
                                .font(.digitalTimer(48))
                                .foregroundStyle(.white)
                            Text("\(appState.occupancyInClub) of \(appState.occupancyCapacity) in the club")
                                .font(.brand(16))
                                .foregroundStyle(.white.opacity(0.75))
                                .padding(.bottom, 6)
                        }

                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(appState.occupancyHourly.indices, id: \.self) { i in
                                let entry = appState.occupancyHourly[i]
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(entry.hour == appState.occupancyNowHour ? Color.appAccent : .white.opacity(0.7))
                                    .frame(height: max(4, entry.value * 100))
                            }
                        }
                        .frame(height: 100, alignment: .bottom)
                        .padding(.top, 12)
                        HStack {
                            ForEach(appState.occupancyHourly.indices, id: \.self) { i in
                                Text(appState.occupancyHourly[i].hour)
                                    .font(.brand(10))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .glassCard(padding: 18)

                    HStack(spacing: 10) {
                        infoTile(title: "Quietest", value: quietestHour, color: .appSuccess)
                        infoTile(title: "Busiest", value: busiestHour, color: .appAccent)
                    }
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Occupancy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
        }
    }

    private func infoTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.digitalTimer(28)).foregroundStyle(color)
            Text(title.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.4).foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

#Preview {
    OccupancyDetailView()
        .environmentObject(AppState())
}
