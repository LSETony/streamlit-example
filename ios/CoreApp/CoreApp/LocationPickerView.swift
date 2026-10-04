import SwiftUI
import MapKit

/// Opened by tapping the club name on Home. Shows every real club location
/// as a pin on an actual map (6 locations: Moscow, 2 in Dubai, 3 in the
/// US), plus a quick-pick strip underneath for exact selection when pins
/// overlap at a world-zoomed-out camera. Picking one updates appState's
/// current location (real address/coordinates/hours/description per
/// location — see AppState.gymLocations) and chains into GymPhotoViewer,
/// same flow as before.
struct LocationPickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    /// Called right before dismissing, once a location has been tapped —
    /// the caller uses this to chain straight into that location's photo
    /// and info sheet (GymPhotoViewer), matching the "pick a location ->
    /// its detail card opens" reference flow.
    var onSelect: () -> Void = {}

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
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
