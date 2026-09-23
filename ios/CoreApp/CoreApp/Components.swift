import SwiftUI
import AVKit
import UIKit

extension Image {
    /// A custom vector icon from the design's SVG export, sized and tinted
    /// like a system symbol would be via `.font(size:)` + `.foregroundStyle`.
    func customIcon(size: CGFloat) -> some View {
        self.renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

/// A WorkoutCard's cover photo. Priority: a real photo uploaded to
/// Supabase Storage (card.imageURL) — then, if only a video was
/// uploaded, a frame grabbed live from that video — then the bundled
/// asset (card.imageName) as a last resort. This is what makes card
/// list thumbnails (which never show the live video, only
/// WorkoutDetailView's hero does) reflect the real uploaded footage
/// instead of a reused generic photo. Callers apply their own
/// `.frame`/`.clipped`; this view always fills.
struct WorkoutCoverImage: View {
    let card: WorkoutCard
    @State private var videoFrame: Image?

    var body: some View {
        Group {
            if let url = card.imageURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
    }

    @ViewBuilder
    private var fallback: some View {
        if let videoFrame {
            videoFrame.resizable().scaledToFill()
        } else {
            Image(card.imageName)
                .resizable()
                .scaledToFill()
                .task(id: card.videoURL) {
                    guard let videoURL = card.videoURL else { return }
                    videoFrame = await Self.grabFrame(from: videoURL)
                }
        }
    }

    private static func grabFrame(from url: URL) async -> Image? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        do {
            let cgImage = try await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600)).image
            return Image(decorative: cgImage, scale: 1)
        } catch {
            return nil
        }
    }
}

/// A WorkoutCard's hero video — a real video uploaded to Supabase Storage,
/// played muted and looping (like a Live Photo). Nothing renders when
/// card.videoURL is nil; callers should keep the cover photo underneath.
/// Uses a bare AVPlayerLayer (not SwiftUI's VideoPlayer) because
/// VideoPlayer always shows native playback controls, which a background
/// loop shouldn't have.
struct WorkoutHeroVideo: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .none
        view.playerLayer.player = player
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {}

    final class PlayerLayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override init(frame: CGRect) {
            super.init(frame: frame)
            playerLayer.videoGravity = .resizeAspectFill
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
}

/// Horizontal progress bar used by the Home "Your Progress" card.
struct ProgressBarView: View {
    let value: Double // 0...1
    var color: Color = .appAccent
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(color)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

/// Full-width call-to-action button used across screens ("Continue",
/// "Logout", "Add to cart" ...) — real Liquid Glass via the system's
/// `.glassProminent` button style, tinted per call site.
struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var color: Color = .appAccent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.brand(20))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.glassProminent)
        .tint(color)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Divider matching the app's subtle line color.
struct AppDivider: View {
    var body: some View {
        Rectangle().fill(Color.appDivider).frame(height: 1)
    }
}

/// A themed gradient stand-in for a dish photo — there's no licensed food
/// photography to embed yet, so this keeps Food recipes' exact card shapes
/// while staying honest that it isn't a real photo. Swap in `Image(...)`
/// here once real shots exist.
struct PhotoPlaceholder: View {
    var icon: String? = nil

    private let colors = [Color(red: 0.24, green: 0.14, blue: 0.06), Color(red: 0.06, green: 0.035, blue: 0.02)]

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.white.opacity(0.22))
            }
        }
    }
}

/// Small circular favorite/heart toggle used on trainer cards.
struct FavoriteButton: View {
    @Binding var isFavorite: Bool

    var body: some View {
        Button { isFavorite.toggle() } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.appAccent : .white)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .glassCircleButton()
    }
}
