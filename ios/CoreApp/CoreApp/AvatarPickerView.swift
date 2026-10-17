import SwiftUI
import PhotosUI

/// A colored-circle + SF Symbol avatar option — no new bundled art needed,
/// consistent with the app's icon-centric visual language elsewhere.
struct AvatarPreset: Identifiable {
    let id: String
    let icon: String
    let color: Color
}

enum AvatarPresets {
    static let all: [AvatarPreset] = [
        AvatarPreset(id: "flame", icon: "flame.fill", color: .appAccent),
        AvatarPreset(id: "bolt", icon: "bolt.fill", color: .appAccentPurple),
        AvatarPreset(id: "dumbbell", icon: "dumbbell.fill", color: .appSuccess),
        AvatarPreset(id: "trophy", icon: "trophy.fill", color: .appWarning),
        AvatarPreset(id: "star", icon: "star.fill", color: .appAccentPurple),
        AvatarPreset(id: "leaf", icon: "leaf.fill", color: .appSuccess),
        AvatarPreset(id: "moon", icon: "moon.stars.fill", color: .appAccent),
        AvatarPreset(id: "person", icon: "person.fill", color: Color(red: 0.4, green: 0.42, blue: 0.47)),
    ]

    static func byID(_ id: String?) -> AvatarPreset? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}

/// Resolves and renders the member's avatar: an uploaded photo, else a
/// chosen preset, else initials on a plain fill — used in ProfileView's
/// header and AvatarPickerView's own preview, so both always agree.
struct AvatarView: View {
    let appState: AppState
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let url = appState.avatarImageURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else if let preset = AvatarPresets.byID(appState.avatarPresetID) {
                ZStack {
                    preset.color
                    Image(systemName: preset.icon)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(.white)
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.appDivider, lineWidth: 1))
    }

    private var fallback: some View {
        ZStack {
            Color.appSurfaceElevated
            Text(appState.initials)
                .font(.brand(size * 0.32))
                .foregroundStyle(.white)
        }
    }
}

/// Opened by tapping the avatar in ProfileView — upload a real photo, or
/// pick one of the preset icon avatars.
struct AvatarPickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploading = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    AvatarView(appState: appState, size: 104)
                        .padding(.top, 8)

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        HStack(spacing: 8) {
                            if isUploading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "photo.on.rectangle.angled")
                            }
                            Text(isUploading ? "Uploading…" : "Upload a Photo")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.appAccentPurple).interactive(), in: RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                    .disabled(isUploading)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("OR CHOOSE AN AVATAR")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(Color.appTextSecondary)
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(AvatarPresets.all) { preset in
                                presetTile(preset)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .screenPadding()
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    isUploading = true
                    defer { isUploading = false; pickerItem = nil }
                    guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                    await appState.uploadAvatarPhoto(data)
                }
            }
        }
    }

    private func presetTile(_ preset: AvatarPreset) -> some View {
        let isSelected = appState.avatarImageURL == nil && appState.avatarPresetID == preset.id
        return Button {
            appState.selectAvatarPreset(preset.id)
        } label: {
            ZStack {
                Circle().fill(preset.color)
                Image(systemName: preset.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)
            .overlay(Circle().stroke(isSelected ? .white : .clear, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AvatarPickerView()
        .environmentObject(AppState())
}
