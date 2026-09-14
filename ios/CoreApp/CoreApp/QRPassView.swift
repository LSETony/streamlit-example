import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

struct QRPassView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        EyebrowLabel(text: "Turnstile · reception")
                        Text(appState.isCheckedIn ? "Checked in" : "Check in")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 18) {
                        QRCodeImage(payload: appState.qrPayload)
                            .frame(width: 190, height: 190)
                            .padding(12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        VStack(spacing: 4) {
                            Text(appState.memberCode)
                                .font(.digitalTimer(18))
                                .foregroundStyle(.white)
                            Text("Code refreshes every 30 seconds")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.appTextSecondary)
                        }

                        PrimaryButton(title: appState.isCheckedIn ? "Check out" : "Confirm check-in") {
                            appState.confirmCheckIn()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowLabel(text: "Recent visits")
                        ForEach(appState.visits) { visit in
                            HStack {
                                Text("\(visit.date) · \(visit.zone)")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(visit.timeRange)
                                    .font(.digitalTimer(13))
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                            .padding(.vertical, 12)
                            AppDivider()
                        }
                    }
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { appState.startQRRotation() }
        }
    }
}

/// Generates a real, scannable QR code on-device via Core Image — no
/// network call and no third-party dependency.
struct QRCodeImage: View {
    let payload: String

    var body: some View {
        if let uiImage = Self.generate(from: payload) {
            Image(uiImage: uiImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Color.white
        }
    }

    private static func generate(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    QRPassView()
        .environmentObject(AppState())
}
