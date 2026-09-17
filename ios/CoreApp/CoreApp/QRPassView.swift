import SwiftUI
import CoreImage.CIFilterBuiltins

/// Opened from Profile's "QR access pass" row — shows the member's own
/// QR code full-screen so it can be scanned by the turnstile/reception
/// on the way into the gym. Generated locally with CoreImage; no backend
/// exists yet, so the payload is just a stable per-member identifier.
struct QRPassView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 0)

                VStack(spacing: 16) {
                    if let qrImage = Self.generateQRCode(from: "core-member:\(appState.fullName)") {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                    }
                    VStack(spacing: 3) {
                        Text(appState.fullName)
                            .font(.brand(20))
                            .foregroundStyle(.black)
                        Text("Member since \(appState.memberSince)")
                            .font(.system(size: 12))
                            .foregroundStyle(.black.opacity(0.55))
                    }
                }
                .padding(28)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))

                Text("Show this code at the turnstile or reception to check in")
                    .font(.system(size: 13))
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
        }
    }

    private static func generateQRCode(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    QRPassView()
        .environmentObject(AppState())
}
