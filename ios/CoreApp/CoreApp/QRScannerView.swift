import SwiftUI
import AVFoundation

/// Full-screen camera QR scanner opened from Profile's "QR access pass"
/// row. Reads any QR code via AVFoundation. The Simulator has no camera —
/// `AVCaptureDevice.default(for: .video)` reliably returns nil there — so
/// this degrades to a plain "camera unavailable" message instead of
/// attempting (and failing) to start a capture session.
struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void
    @State private var isCameraAvailable = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isCameraAvailable {
                QRScannerRepresentable(
                    onScan: { code in
                        onScan(code)
                        dismiss()
                    },
                    onUnavailable: { isCameraAvailable = false }
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
                        .stroke(Color.appAccent, lineWidth: 3)
                        .frame(width: 240, height: 240)
                    Text("Point the camera at a QR code")
                        .font(.brand(16))
                        .foregroundStyle(.white)
                        .padding(.top, 16)
                    Spacer()
                }
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "camera.metering.unknown")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.appTextSecondary)
                    Text("Camera unavailable")
                        .font(.brand(20))
                        .foregroundStyle(.white)
                    Text("QR scanning needs a real device with a camera.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .screenPadding()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .glassCircleButton()
            }
            .padding(20)
        }
    }
}

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onUnavailable: () -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.onScan = onScan
        controller.onUnavailable = onUnavailable
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {}
}

private final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    var onUnavailable: (() -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            onUnavailable?()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onUnavailable?()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        let capturedSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            capturedSession.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue
        else { return }
        session.stopRunning()
        onScan?(value)
    }

    deinit {
        session.stopRunning()
    }
}

#Preview {
    QRScannerView { _ in }
}
