import SwiftUI
import PhotosUI

/// Before/after photo gallery — opened from ProgressDetailView. Photos are
/// picked with PhotosPicker (out-of-process; no photo-library usage
/// description needed, unlike UIImagePickerController) and uploaded to the
/// shared `media` Storage bucket via AppState.uploadProgressPhoto — see
/// its doc comment for the privacy caveat (same public-bucket trust model
/// as the rest of this app's media).
struct ProgressPhotosView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploading = false

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Progress Photos")
                            .font(.brand(32))
                            .foregroundStyle(.white)
                        Text("A private before/after timeline — newest first.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        HStack(spacing: 8) {
                            if isUploading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text(isUploading ? "Uploading…" : "Add a photo")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.appAccent).interactive(), in: RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                    .disabled(isUploading)

                    if appState.progressPhotos.isEmpty {
                        Text("No photos yet — add your first to start the timeline.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.appTextSecondary)
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(appState.progressPhotos) { photo in
                                photoTile(photo)
                            }
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
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    isUploading = true
                    defer { isUploading = false; pickerItem = nil }
                    guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                    await appState.uploadProgressPhoto(data)
                }
            }
        }
    }

    private func photoTile(_ photo: ProgressPhoto) -> some View {
        AsyncImage(url: photo.imageURL) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFill()
            } else {
                Color.appSurface
            }
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Text(photo.takenAt.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.5))
                .clipShape(Capsule())
                .padding(8)
        }
        .contextMenu {
            Button("Delete", role: .destructive) {
                Task { await appState.deleteProgressPhoto(photo) }
            }
        }
    }
}

#Preview {
    ProgressPhotosView()
        .environmentObject(AppState())
}
