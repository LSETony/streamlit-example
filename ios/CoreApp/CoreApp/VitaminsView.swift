import SwiftUI

/// The vitamins protocol list, reused inside the Diagnostics "Vitamins" tab.
struct VitaminsListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your protocol, derived from the panel. Tap an item for dosage, benefits and interactions.")
                .font(.system(size: 13))
                .foregroundStyle(Color.appTextSecondary)

            ForEach(appState.vitamins) { item in
                Button {
                    appState.toggleVitamin(item)
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.appAccentDim)
                            Text(item.symbol)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.appAccent)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(item.dosage)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        Spacer()
                        StatusBadge(text: item.status.rawValue, color: item.status.color)
                    }
                    .padding(14)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    ScrollView { VitaminsListView().screenPadding() }
        .background(Color.appBackground)
        .environmentObject(AppState())
}
