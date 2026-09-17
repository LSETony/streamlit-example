import SwiftUI

/// Full-screen viewer opened by tapping the Home hero photo. Only one real
/// gym-interior photo exists in the source assets right now, so this shows
/// that photo large rather than faking a multi-photo gallery.
struct GymPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image("HomeHero")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .padding(.top, 14)
            .padding(.trailing, 20)
        }
        .onTapGesture { dismiss() }
    }
}

#Preview {
    GymPhotoViewer()
}
