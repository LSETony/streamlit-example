import SwiftUI
import MapKit

/// Opened by tapping the club name on Home. Defaults to a list of every
/// real club location (6: Moscow, 2 in Dubai, 3 in the US), grouped by
/// city — a map-icon button top-left switches to a live MapKit view with a
/// pin per location, matching the reference flow (list by default, map one
/// tap away). Picking a location either way updates AppState's current
/// location (real address/coordinates/hours/description — see
/// AppState.gymLocations) and chains into GymPhotoViewer, same as before.
struct LocationPickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    /// Called right before dismissing, once a location has been tapped —
    /// the caller uses this to chain straight into that location's photo
    /// and info sheet (GymPhotoViewer), matching the "pick a location ->
    /// its detail card opens" reference flow.
    var onSelect: () -> Void = {}

    @State private var isShowingMap = false
    @State private var cameraPosition: MapCameraPosition = .automatic

    private var citiesInOrder: [String] {
        var seen: [String] = []
        for location in appState.gymLocations where !seen.contains(location.city) {
            seen.append(location.city)
        }
        return seen
    }

    var body: some View {
        NavigationStack {
            Group {
                if isShowingMap {
                    mapView
                } else {
                    listView
                }
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingMap.toggle()
                    } label: {
                        Image(systemName: isShowingMap ? "list.bullet" : "map.fill")
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                    }
                    .glassEffect(.regular.interactive(), in: Circle())
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
    }

    // MARK: List (default)

    private var listView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(citiesInOrder, id: \.self) { city in
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowLabel(text: city)
                        GlassEffectContainer(spacing: 10) {
                            VStack(spacing: 10) {
                                ForEach(appState.gymLocations.filter { $0.city == city }) { location in
                                    locationRow(location)
                                }
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
    }

    private func locationRow(_ location: GymLocation) -> some View {
        let isSelected = location.name == appState.clubName
        return Button { choose(location) } label: {
            HStack(spacing: 14) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .glassEffect(.regular.tint(isSelected ? .appAccent : .clear), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(location.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(location.address)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)
                    Text(location.hoursLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.appTextSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.appAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(
                isSelected ? .regular.tint(.appAccent.opacity(0.35)).interactive() : .regular.interactive(),
                in: RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                    .stroke(.white.opacity(isSelected ? 0.3 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Map (toggled via the top-left icon)

    private var mapView: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                ForEach(appState.gymLocations) { location in
                    Annotation(location.name, coordinate: location.coordinate) {
                        pin(for: location)
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .ignoresSafeArea(edges: .bottom)

            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(appState.gymLocations) { location in
                            locationChip(location)
                        }
                    }
                }
                .padding(.horizontal, AppMetrics.screenPadding)
            }
            .padding(.bottom, 18)
        }
    }

    private func pin(for location: GymLocation) -> some View {
        let isSelected = location.name == appState.clubName
        return Button { choose(location) } label: {
            VStack(spacing: 2) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .glassEffect(.regular.tint(isSelected ? .appAccent : .appAccentPurple), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
                Image(systemName: "triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? Color.appAccent : Color.appAccentPurple)
                    .rotationEffect(.degrees(180))
                    .offset(y: -6)
            }
        }
        .buttonStyle(.plain)
    }

    private func locationChip(_ location: GymLocation) -> some View {
        let isSelected = location.name == appState.clubName
        return Button { choose(location) } label: {
            Text(location.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(
                    isSelected ? .regular.tint(.appAccent).interactive() : .regular.interactive(),
                    in: Capsule()
                )
                .overlay(Capsule().stroke(.white.opacity(isSelected ? 0.3 : 0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func choose(_ location: GymLocation) {
        appState.clubName = location.name
        onSelect()
        dismiss()
    }
}

#Preview {
    LocationPickerView()
        .environmentObject(AppState())
}
