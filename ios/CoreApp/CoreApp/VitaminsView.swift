import SwiftUI

/// The vitamins protocol list, reused inside the Diagnostics "Vitamins" tab.
struct VitaminsListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showStore = false
    @State private var showScanner = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 7) {
                Text("TODAY'S PROTOCOL · \(appState.vitaminsTakenLabel)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appTextSecondary)

                VStack(spacing: 0) {
                    ForEach(Array(appState.vitamins.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            Button {
                                appState.toggleVitamin(item)
                            } label: {
                                ZStack {
                                    Circle().fill(item.status == .taken ? Color.appAccent : Color.clear)
                                    Circle().stroke(item.status == .taken ? .clear : Color.appDivider, lineWidth: 1.5)
                                    if item.status == .taken {
                                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                    }
                                }
                                .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(.system(size: 16)).foregroundStyle(.white)
                                Text(item.dosage).font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, 16)
                        if index < appState.vitamins.count - 1 { AppDivider() }
                    }
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Set by Elena after the 02 Sep panel. Tap a row for dosage, benefits, risks and interactions.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("SUPPLY").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                VStack(spacing: 0) {
                    HStack {
                        Text("Iron bisglycinate").font(.system(size: 16)).foregroundStyle(.white)
                        Spacer()
                        Text("6 days left").font(.system(size: 15)).foregroundStyle(Color.appWarning)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    AppDivider()
                    Button { showStore = true } label: {
                        HStack {
                            Text("Reorder for club pickup").font(.system(size: 16)).foregroundStyle(Color.appAccent)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                    AppDivider()
                    Button { showScanner = true } label: {
                        HStack {
                            Text("Scan a label you already own").font(.system(size: 16)).foregroundStyle(Color.appAccent)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .sheet(isPresented: $showStore) { NavigationStack { StoreView() } }
        .sheet(isPresented: $showScanner) { NavigationStack { ScannerView() } }
    }
}

#Preview {
    ScrollView { VitaminsListView().screenPadding() }
        .background(Color.appBackground)
        .environmentObject(AppState())
}
