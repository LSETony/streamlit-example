import SwiftUI

/// Opened from Home's "Book" tile — lets a member reserve a slot in one of
/// the club's bookable zones (Pilates studio, running track, ...). A
/// confirmed booking is added to appState.bookedSessions, so it shows up
/// alongside trainer sessions in the Calendar tab.
struct BookZoneView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedZone: GymZone?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Book a Zone")
                        .font(.brand(32))
                        .foregroundStyle(.white)
                    VStack(spacing: 10) {
                        ForEach(appState.gymZones) { zone in
                            zoneRow(zone)
                        }
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
            .sheet(item: $selectedZone) { zone in
                NavigationStack { ZoneBookingView(zone: zone) }
            }
        }
    }

    private func zoneRow(_ zone: GymZone) -> some View {
        Button { selectedZone = zone } label: {
            HStack(spacing: 14) {
                Image(systemName: zone.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.appAccentPurple)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(zone.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    Text(zone.subtitle).font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(zone.capacity)").font(.digitalTimer(16)).foregroundStyle(.white)
                    Text("cap.").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.appTextSecondary)
                }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.appTextSecondary)
            }
            .padding(14)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Time-slot picker for one zone, pushed from BookZoneView's list.
private struct ZoneBookingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let zone: GymZone
    @State private var selectedSlot: String = ""
    @State private var didBook = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: zone.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.appAccentPurple)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(zone.name).font(.brand(22)).foregroundStyle(.white)
                        Text(zone.subtitle).font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: "Next free slots")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ForEach(appState.trainerSlots, id: \.self) { slot in
                            let on = selectedSlot == slot
                            Text(slot)
                                .font(.digitalTimer(15))
                                .foregroundStyle(on ? .white : Color.appTextPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(on ? Color.appAccent : Color.appSurface)
                                .overlay(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous).stroke(on ? .clear : Color.appDivider, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                                .onTapGesture { selectedSlot = slot }
                        }
                    }
                }

                PrimaryButton(
                    title: didBook ? "✓ Booked \(zone.name) · \(selectedSlot)" : "Book \(zone.name) · \(selectedSlot)",
                    isEnabled: !didBook,
                    color: .appAccentPurple
                ) {
                    appState.bookZone(zone, at: selectedSlot)
                    didBook = true
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
        .onAppear { selectedSlot = appState.trainerSlots.first ?? "" }
    }
}

#Preview {
    BookZoneView()
        .environmentObject(AppState())
}
