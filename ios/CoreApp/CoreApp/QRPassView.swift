import SwiftUI
import CoreImage.CIFilterBuiltins

/// Opened from Profile's "QR access pass" row — the member's gym pass,
/// shown full-screen for the reception scanner. The code comes from the
/// core. platform (CoreMemberService.qrPayload): it changes every 30
/// seconds and is signed with this iPhone's secret, so a screenshot or a
/// forwarded picture stops working within a minute.
struct QRPassView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var core: CoreMemberService
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingJoin = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 0)

                if core.isLinked, core.device != nil {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        passCard(at: context.date)
                    }
                } else {
                    notLinkedCard
                }

                Text("Show this code at the turnstile or reception to check in")
                    .font(.uiText(size: 13))
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .screenPadding()

                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
            .task {
                if core.isLinked && core.device == nil { await core.registerDevice() }
            }
            .sheet(isPresented: $isShowingJoin) { CoreJoinGymView() }
        }
    }

    private func passCard(at date: Date) -> some View {
        let secondsLeft = 30 - Int(date.timeIntervalSince1970) % 30
        return VStack(spacing: 16) {
            if let payload = core.qrPayload(at: date), let qrImage = Self.qrImage(for: payload) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
            }
            ProgressView(value: Double(secondsLeft), total: 30)
                .tint(.appAccentPurple)
                .frame(width: 140)
                .animation(.linear(duration: 1), value: secondsLeft)
            VStack(spacing: 3) {
                Text(core.currentClient?.fullName ?? appState.fullName)
                    .font(.brand(20))
                    .foregroundStyle(.black)
                Text(core.gym?.name ?? "")
                    .font(.uiText(size: 12))
                    .foregroundStyle(.black.opacity(0.55))
                Text("Refreshes in \(secondsLeft) s")
                    .font(.uiText(size: 12))
                    .foregroundStyle(.black.opacity(0.45))
                    .monospacedDigit()
            }
        }
        .padding(28)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    private var notLinkedCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "qrcode")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(Color.appTextSecondary)
            Text("Your pass appears once you're a client of your gym")
                .font(.brand(20))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if core.phase == .loading {
                ProgressView().tint(.white)
            } else {
                PrimaryButton(title: "Choose your gym", color: .appAccentPurple) { isShowingJoin = true }
                    .frame(maxWidth: 260)
            }
        }
        .padding(28)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
        .screenPadding()
    }

    /// The same payload is reused for a whole 30-second window, so cache the
    /// rendered image instead of regenerating it every second.
    @MainActor private static var cache: (payload: String, image: UIImage)?

    @MainActor private static func qrImage(for payload: String) -> UIImage? {
        if let cache, cache.payload == payload { return cache.image }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache = (payload, image)
        return image
    }
}

#Preview {
    QRPassView()
        .environmentObject(AppState())
        .environmentObject(CoreMemberService())
}
