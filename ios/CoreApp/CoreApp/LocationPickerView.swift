import SwiftUI

/// Opened by tapping the club name on Home. Lets the member switch which
/// club location the app is showing. Only one location has real data in
/// this build — the source hasn't designed a multi-location Home yet — so
/// picking another just renames the header, honestly, rather than faking
/// content that doesn't exist.
struct LocationPickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(appState.clubLocations, id: \.self) { location in
                        let isSelected = location == appState.clubName
                        Button {
                            appState.clubName = location
                            dismiss()
                        } label: {
                            HStack {
                                Text(location)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(Color.appSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                                    .stroke(isSelected ? Color.appAccent : Color.appDivider, lineWidth: isSelected ? 2 : 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    LocationPickerView()
        .environmentObject(AppState())
}
