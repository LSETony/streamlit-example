import SwiftUI
import UIKit

/// A single Dynamic-Island-style in-app notification. Native SwiftUI
/// equivalent of the "expo-dynamic-notifications" look (that library is
/// React Native/Expo-only — react-native-skia, reanimated — and can't be
/// installed into this native Swift target, so this recreates the same
/// morphing pill effect directly in SwiftUI/UIKit).
struct DynamicNotification: Identifiable, Equatable {
    let id = UUID()
    var icon: String = "bell.fill"
    var title: String
    var subtitle: String? = nil
    var accent: Color = .appAccent
    var duration: TimeInterval = 3
}

/// Queues and displays Dynamic Island-style notifications in a dedicated
/// overlay `UIWindow` above the key window, so a notification stays
/// visible even over a presented sheet or full-screen cover — the same way
/// the real system Dynamic Island floats above everything. Call
/// `appState.notificationCenter.trigger(...)` from anywhere; no view
/// modifier needs to be attached for this to show up.
@MainActor
final class DynamicNotificationCenter: ObservableObject {
    @Published fileprivate var current: DynamicNotification?
    private var queue: [DynamicNotification] = []
    private var dismissTask: Task<Void, Never>?
    private var overlayWindow: UIWindow?

    func trigger(_ notification: DynamicNotification) {
        queue.append(notification)
        advanceIfNeeded()
    }

    func trigger(icon: String = "bell.fill", title: String, subtitle: String? = nil, accent: Color = .appAccent, duration: TimeInterval = 3) {
        trigger(DynamicNotification(icon: icon, title: title, subtitle: subtitle, accent: accent, duration: duration))
    }

    /// Dismisses whatever is currently showing (used by swipe-to-dismiss
    /// and tap-to-dismiss) and advances to the next queued notification.
    func dismissCurrent() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            current = nil
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            self?.advanceIfNeeded()
        }
    }

    private func advanceIfNeeded() {
        guard current == nil else { return }
        guard !queue.isEmpty else {
            hideWindow()
            return
        }
        let next = queue.removeFirst()
        showWindow()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            current = next
        }
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(next.duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dismissCurrent()
        }
    }

    private func showWindow() {
        guard overlayWindow == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        window.backgroundColor = .clear
        let host = UIHostingController(rootView: DynamicIslandOverlay(center: self))
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false
        overlayWindow = window
    }

    private func hideWindow() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
    }
}

/// A `UIWindow` that only intercepts touches landing on a real subview
/// (the notification pill itself) — taps anywhere else on screen fall
/// straight through to the app underneath.
private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        return hit == rootViewController?.view ? nil : hit
    }
}

private struct DynamicIslandOverlay: View {
    @ObservedObject var center: DynamicNotificationCenter

    var body: some View {
        VStack {
            if let notification = center.current {
                DynamicIslandNotificationView(notification: notification) {
                    center.dismissCurrent()
                }
                .padding(.top, 11)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.4, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.5, anchor: .top).combined(with: .opacity)
                ))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .ignoresSafeArea()
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: center.current)
    }
}

/// The pill itself — dark capsule with an accent-tinted icon badge, title
/// and optional subtitle, sized and positioned like the real Dynamic
/// Island. Swipe up (or tap) to dismiss early.
private struct DynamicIslandNotificationView: View {
    let notification: DynamicNotification
    var onDismiss: () -> Void
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: notification.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(notification.accent)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(notification.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let subtitle = notification.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 200, maxWidth: 320)
        .background(.black, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        .offset(y: min(dragOffset, 0))
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    if value.translation.height < -20 {
                        onDismiss()
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onTapGesture { onDismiss() }
    }
}
