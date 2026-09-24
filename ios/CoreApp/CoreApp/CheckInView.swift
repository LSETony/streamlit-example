import SwiftUI
import UIKit
import VisionKit
import CoreImage.CIFilterBuiltins

/// Opened from Home's "Check In" tile — a self-service check-in, the same
/// pattern real gyms use: scan a QR code posted at reception (or shown on
/// a screen there) to log a visit, instead of staff having to scan the
/// member's own QR pass (QRPassView) by hand every time. A successful scan
/// feeds the same streak/visit tracking as finishing a workout in-app (see
/// AppState+Growth.swift's recordActivity()).
struct CheckInView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isCheckedIn = false
    @State private var isShowingTestCode = false

    /// What the reception's poster/screen QR is expected to encode. Real
    /// deployment: print this as a QR and put it at the front desk. For
    /// testing without a poster yet, "Show check-in code" below renders
    /// the same code on screen so it can be scanned from a second device.
    static let expectedCode = "core.checkin.v1"

    private var isScannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isCheckedIn {
                    successState
                } else if isScannerAvailable {
                    CheckInScannerRepresentable { code in
                        handleScanned(code)
                    }
                    .ignoresSafeArea()
                } else {
                    unavailableState
                }

                if !isCheckedIn {
                    VStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Text("Scan the check-in QR at reception")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .glassEffect(.regular, in: Capsule())
                            Button("Don't have a code? Show a test one") { isShowingTestCode = true }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.appAccent)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $isShowingTestCode) {
                CheckInPosterView()
                    .presentationDetents([.medium])
            }
        }
    }

    private func handleScanned(_ code: String) {
        guard !isCheckedIn, code == Self.expectedCode else { return }
        isCheckedIn = true
        Task {
            let leveledUp = await appState.recordActivity()
            await MainActor.run {
                appState.notificationCenter.trigger(
                    icon: "checkmark.circle.fill", title: "Checked in!",
                    subtitle: leveledUp ? "\(appState.streakDays)-day streak" : "Visit logged", accent: .appSuccess
                )
            }
        }
    }

    private var successState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.appSuccess)
            Text("You're checked in!")
                .font(.brand(24))
                .foregroundStyle(.white)
            Text("\(appState.streakDays)-day streak · \(appState.totalVisits) total visits")
                .font(.system(size: 13))
                .foregroundStyle(Color.appTextSecondary)
            PrimaryButton(title: "Done") { dismiss() }
                .padding(.top, 8)
                .padding(.horizontal, 40)
        }
    }

    private var unavailableState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 40))
                .foregroundStyle(Color.appTextSecondary)
            Text("Scanning needs a real iPhone camera — it isn't available in the Simulator or on this device.")
                .font(.system(size: 14))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

/// Bridges VisionKit's DataScannerViewController into SwiftUI, running
/// live QR/barcode recognition and reporting each recognized payload.
private struct CheckInScannerRepresentable: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCodeScanned: (String) -> Void

        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    onCodeScanned(payload)
                }
            }
        }
    }
}

/// Renders CheckInView.expectedCode as an on-screen QR — either for
/// testing the scan flow with a second device, or as what reception would
/// actually print and post at the front desk.
private struct CheckInPosterView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Check-in code")
                .font(.brand(20))
                .foregroundStyle(.white)
            if let image = Self.qrImage(for: CheckInView.expectedCode) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
            }
            Text("Print this at reception, or scan it from another device to test check-in.")
                .font(.system(size: 12))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
    }

    private static func qrImage(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    CheckInView()
        .environmentObject(AppState())
}
