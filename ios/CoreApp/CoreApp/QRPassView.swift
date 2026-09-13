import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

struct QRPassView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 14) {
                        QRCodeImage(payload: appState.qrPayload)
                            .frame(width: 200, height: 200)
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        Text(appState.memberCode)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)

                        Text("Code refreshes in \(appState.qrSecondsRemaining)s")
                            .font(.system(size: 13))
                            .foregroundStyle(.appTextSecondary)

                        PrimaryButton(title: "Confirm check-in") {
                            appState.confirmCheckIn()
                        }

                        if let lastCheckIn = appState.lastCheckIn {
                            Text(lastCheckIn)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.appSuccess)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowLabel(text: "Recent visits")
                        ForEach(appState.visits) { visit in
                            HStack {
                                Text("\(visit.date) · \(visit.zone)")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(visit.timeRange)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.appTextSecondary)
                            }
                            AppDivider()
                        }
                    }
                }
                .screenPadding()
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Pass")
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
