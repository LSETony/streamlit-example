import Foundation
import Supabase

/// Backs AvatarPickerView — uploading a photo or picking a preset. Same
/// public `media` Storage bucket as progress photos (see
/// AppState+Growth.swift's uploadProgressPhoto), under its own
/// `avatars/<device>/...` prefix (supabase/add_avatar_storage_policy.sql).
extension AppState {
    /// Uploads a freshly picked photo and points avatarImageURLString at
    /// it, clearing any preset selection. A fresh UUID filename each time
    /// (rather than overwriting one fixed path) avoids needing an UPDATE
    /// storage policy on top of the existing INSERT-only one — old
    /// uploads for this device are just left in Storage, harmless clutter
    /// for a demo app.
    func uploadAvatarPhoto(_ imageData: Data) async {
        let path = "avatars/\(DeviceUser.id)/\(UUID().uuidString).jpg"
        do {
            try await supabase.storage.from("media").upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))
            let publicURL = try supabase.storage.from("media").getPublicURL(path: path)
            avatarImageURLString = publicURL.absoluteString
            avatarPresetID = nil
        } catch {
            print("Supabase uploadAvatarPhoto failed: \(error)")
            notificationCenter.trigger(
                icon: "exclamationmark.triangle.fill", title: "Couldn't upload photo",
                subtitle: "Check your connection and try again", accent: .appAccent
            )
        }
    }

    /// Picks one of AvatarPresets.all, clearing any uploaded photo.
    func selectAvatarPreset(_ id: String) {
        avatarPresetID = id
        avatarImageURLString = nil
    }
}
