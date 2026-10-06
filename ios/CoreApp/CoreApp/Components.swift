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

/// A WorkoutCard's cover photo — a real photo uploaded to Supabase Storage
/// (card.imageURL) when set, otherwise the bundled asset (card.imageName).
/// Callers apply their own `.frame`/`.clipped`; this view always fills.
struct WorkoutCoverImage: View {
    let card: WorkoutCard

    var body: some View {
        if let url = card.imageURL {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Image(card.imageName).resizable().scaledToFill()
                }
            }
        } else {
            Image(card.imageName).resizable().scaledToFill()
        }
    }
}

/// Backing UIView for both video components below — a bare AVPlayerLayer
/// (not SwiftUI's VideoPlayer, which always shows native playback
/// controls, wrong for a background loop).
final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspectFill
        // This is always a decorative background loop, never itself
        // interactive — without this, the full-bleed UIKit view can
        // intercept the first tap on a SwiftUI button layered on top of it
        // (e.g. Home's wallet icon over the hero video), so the button
        // looks "stuck" and needs a second tap to register.
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// A WorkoutCard's hero video — a real video uploaded to Supabase Storage,
/// played muted and looping (like a Live Photo). Nothing renders when
/// card.videoURL is nil; callers should keep the cover photo underneath.
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
}

/// Owns the Home hero's AVQueuePlayer independently of whether HomeView is
/// currently on screen. AppState creates this once at launch, so buffering
/// (such as it is — see below) starts well before the member ever reaches
/// Home.
///
/// Plays HeroVideo.mp4, bundled in the app, on a gapless infinite loop via
/// AVPlayerLooper.
///
/// This has gone through several iterations that all looked right on paper
/// but kept reproducing the same symptom on a real device (video plays,
/// then after some background/foreground cycle it's permanently stuck on
/// HomeView's backdrop photo): a manual seek-to-zero loop, then
/// AVPlayerLooper + just calling play() again on didBecomeActive. Since
/// this sandbox has no simulator/device to actually observe AVFoundation's
/// runtime behavior, the only verifiable-from-code fix left is to stop
/// trying to *resume* whatever state the player/looper/item were left in
/// after backgrounding — any of the three can end up wedged in a way a
/// bare play() doesn't recover from — and instead throw all three away and
/// build fresh ones. A cold app launch always played the video correctly;
/// restart() reproduces exactly that path on every return to foreground.
@MainActor
final class HeroVideoPlayerService: ObservableObject {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var foregroundObserver: NSObjectProtocol?

    init() {
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        restart()
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.restart()
        }
    }

    /// Tears down the current item/looper (if any) and builds both fresh,
    /// then plays — called on init and on every return to foreground.
    func restart() {
        guard let url = Bundle.main.url(forResource: "HeroVideo", withExtension: "mp4") else { return }
        looper = nil
        player.removeAllItems()
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
    }

    deinit {
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
    }
}

/// Displays the Home hero's already-running, already-buffering player
/// (see HeroVideoPlayerService) — this view itself owns no playback state.
struct HeroVideoQueue: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {}
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
    /// Shows a spinner in place of the title and blocks taps — for an
    /// action with a real network step (e.g. starting a Stripe payment)
    /// before anything visibly changes, so the button doesn't just sit
    /// there looking unresponsive while it's in flight.
    var isLoading: Bool = false
    var color: Color = .appAccent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                }
            }
            .font(.brand(20))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.glassProminent)
        .tint(color)
        .disabled(!isEnabled || isLoading)
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
