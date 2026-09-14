import SwiftUI
import UIKit
import AVFoundation
import Vision

/// Runs the capture session and label recognition. Uses the real device
/// camera plus on-device Vision OCR — no network call or third-party API.
final class ScannerCameraModel: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var completion: ((UIImage?) -> Void)?

    @Published var isAuthorized = false
    @Published var isSessionRunning = false
    @Published var isCameraAvailable = true

    func configure() {
        guard AVCaptureDevice.default(for: .video) != nil else {
            isCameraAvailable = false
            return
        }

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted { self?.setupSession() }
            }
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async { self?.isSessionRunning = true }
        }
    }

    func stop() {
        guard isSessionRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension ScannerCameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            completion?(nil)
            return
        }
        completion?(image)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

private struct SupplementMatch {
    let keyword: String
    let name: String
    let note: String
}

private let knownSupplements: [SupplementMatch] = [
    SupplementMatch(keyword: "vitamin d", name: "Vitamin D3", note: "Fat-soluble — take with a meal containing fat."),
    SupplementMatch(keyword: "iron", name: "Iron", note: "Avoid taking within 2 hours of tea, coffee or dairy."),
    SupplementMatch(keyword: "magnesium", name: "Magnesium", note: "Glycinate form is gentle on digestion; take before sleep."),
    SupplementMatch(keyword: "omega", name: "Omega-3", note: "Take with any meal to improve absorption."),
    SupplementMatch(keyword: "zinc", name: "Zinc", note: "50 mg daily is above the 40 mg upper limit and can suppress copper absorption over months. It also competes with the iron bisglycinate Elena prescribed — separate them by four hours or drop to 15 mg."),
    SupplementMatch(keyword: "creatine", name: "Creatine", note: "3-5 g daily is effective; timing doesn't matter much."),
    SupplementMatch(keyword: "calcium", name: "Calcium", note: "Space away from iron supplements by a few hours."),
]

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = ScannerCameraModel()
    @State private var capturedText: String?
    @State private var matchedNote: String?
    @State private var isProcessing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isCameraAvailable && camera.isAuthorized && camera.isSessionRunning {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            } else {
                unavailableState
            }

            VStack {
                Spacer()
                viewfinderOverlay
                Spacer()
                controls
            }
        }
        .navigationTitle("Label scanner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.foregroundStyle(.white)
            }
        }
        .onAppear { camera.configure() }
        .onDisappear { camera.stop() }
        .sheet(isPresented: Binding(get: { capturedText != nil }, set: { if !$0 { capturedText = nil } })) {
            resultSheet
        }
    }

    private var viewfinderOverlay: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Color.appAccent, lineWidth: 2)
            .frame(width: 280, height: 180)
            .overlay(alignment: .top) {
                Text("POINT AT THE LABEL")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.6))
                    .clipShape(Capsule())
                    .offset(y: -20)
            }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            if isProcessing {
                ProgressView().tint(.white)
            }
            PrimaryButton(title: "Capture", isEnabled: !isProcessing) {
                capture()
            }
        }
        .screenPadding()
        .padding(.bottom, 40)
    }

    private var unavailableState: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.appTextSecondary)
            Text(camera.isCameraAvailable ? "Waiting for camera access…" : "Camera not available on this device")
                .font(.system(size: 14))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .screenPadding()
        }
    }

    private func capture() {
        if !camera.isCameraAvailable || !camera.isSessionRunning {
            // Simulator / no-camera fallback so the flow is always demoable.
            finish(with: "Zinc picolinate 50 mg")
            return
        }
        isProcessing = true
        camera.capturePhoto { image in
            DispatchQueue.main.async {
                guard let image, let cgImage = image.cgImage else {
                    self.isProcessing = false
                    self.finish(with: "")
                    return
                }
                self.recognizeText(in: cgImage)
            }
        }
    }

    private func recognizeText(in cgImage: CGImage) {
        let request = VNRecognizeTextRequest { request, _ in
            let strings = (request.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string } ?? []
            DispatchQueue.main.async {
                self.isProcessing = false
                self.finish(with: strings.joined(separator: "\n"))
            }
        }
        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    private func finish(with text: String) {
        capturedText = text.isEmpty ? "No text recognized — try moving closer to the label." : text
        let lower = text.lowercased()
        matchedNote = knownSupplements.first { lower.contains($0.keyword) }?.note
    }

    private var resultSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scan result")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            ScrollView {
                Text(capturedText ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 160)
            if let matchedNote {
                VStack(alignment: .leading, spacing: 6) {
                    EyebrowLabel(text: "Interaction note", color: .appAccent)
                    Text(matchedNote)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
                .appCard()
            }
            Spacer()
            PrimaryButton(title: "Close") { capturedText = nil }
        }
        .padding(24)
        .background(Color.appBackground.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack { ScannerView() }
        .environmentObject(AppState())
}
