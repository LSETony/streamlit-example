import SwiftUI
import Charts

/// Opened by tapping the "Club Occupancy" card on Home. Shows the current
/// reading plus a fuller hour-by-hour breakdown of the day, and the
/// quietest/busiest times to help members plan a visit.
///
/// The big number and "X of Y in the club" are real:
/// AppState.refreshLiveOccupancy() counts distinct members with a
/// `checkins` row in the last couple of hours (see
/// supabase/add_checkins_table.sql and AppState+Growth.swift's
/// recordActivity()/logCheckIn()) — there's no check-out event, so that
/// window stands in for "still here". This view re-reads it once a
/// minute while it's on screen. The hourly bar *shape* is still an
/// illustrative "typical day" curve (same idea as Google Maps' Popular
/// Times, which is itself historically averaged, not a live feed) —
/// building a real per-hour history needs many days of check-in data
/// this fresh install doesn't have yet; refreshOccupancyNow() just
/// re-highlights which bar is "now" on that curve. The chart itself is a
/// native Swift Charts BarMark (matching ProgressDetailView's own
/// charts) instead of hand-rolled rectangles, so it gets real axis marks
/// and animates its own transitions when the data updates.
struct OccupancyDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var quietestHour: AppState.OccupancyPoint? {
        appState.occupancyHourly.min { $0.shape < $1.shape }
    }
    private var busiestHour: AppState.OccupancyPoint? {
        appState.occupancyHourly.max { $0.shape < $1.shape }
    }

    private func hourLabel(_ hour: Int) -> String {
        String(format: "%02d", hour)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Club Occupancy")
                            .font(.brand(24))
                            .foregroundStyle(.white)

                        HStack(alignment: .bottom, spacing: 10) {
                            Text("\(appState.occupancyPercent)")
                                .font(.digitalTimer(48))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                            Text("\(appState.occupancyInClub) of \(appState.occupancyCapacity) in the club")
                                .font(.brand(16))
                                .foregroundStyle(.white.opacity(0.75))
                                .padding(.bottom, 6)
                                .contentTransition(.numericText())
                        }

                        Chart(appState.occupancyHourly) { point in
                            BarMark(
                                x: .value("Hour", hourLabel(point.hour)),
                                y: .value("Occupancy", point.shape)
                            )
                            .foregroundStyle(point.isNow ? Color.appAccent.gradient : Color.white.opacity(0.35).gradient)
                            .cornerRadius(6)
                            .annotation(position: .top) {
                                if point.isNow {
                                    Text("NOW")
                                        .font(.system(size: 9, weight: .bold))
                                        .tracking(0.4)
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                        }
                        .frame(height: 140)
                        .padding(.top, 12)
                        .chartYAxis(.hidden)
                        .chartXAxis {
                            AxisMarks { _ in
                                AxisValueLabel().foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState.occupancyHourly)
                    }
                    .glassCard(padding: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )

                    GlassEffectContainer(spacing: 10) {
                        HStack(spacing: 10) {
                            infoTile(icon: "moon.stars.fill", title: "Quietest", value: quietestHour.map { hourLabel($0.hour) } ?? "--", color: .appSuccess)
                            infoTile(icon: "flame.fill", title: "Busiest", value: busiestHour.map { hourLabel($0.hour) } ?? "--", color: .appAccent)
                        }
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
            .task {
                // Cancels automatically when the view disappears (NavigationStack
                // tears the .task down), so this never keeps ticking in the
                // background once the sheet is closed. refreshLiveOccupancy()
                // is the real reading (recent check-ins); refreshOccupancyNow()
                // just re-highlights the current hour on the shape curve and
                // keeps the number from sitting at a stale value while the
                // network call is in flight.
                await appState.refreshLiveOccupancy()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    guard !Task.isCancelled else { break }
                    withAnimation { appState.refreshOccupancyNow() }
                    await appState.refreshLiveOccupancy()
                }
            }
        }
    }

    private func infoTile(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
            Text(value).font(.digitalTimer(28)).foregroundStyle(.white)
            Text(title.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.4).foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular.tint(color.opacity(0.5)), in: RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    OccupancyDetailView()
        .environmentObject(AppState())
}
