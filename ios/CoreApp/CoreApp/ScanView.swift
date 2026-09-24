import SwiftUI
import VisionKit

/// Opened from Home's "Scan" tile — a real live-camera text scanner
/// (VisionKit's DataScannerViewController, iOS 16+) that reads a
/// supplement label and looks up what it found: first against the club's
/// own Store catalog (appState.products, which already has real
/// description/benefits/risks/interactions), then against a built-in
/// reference of common vitamins (VitaminDatabase) so it's useful even for
/// products the club doesn't sell.
struct ScanView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var scannedResult: ScanResult?

    enum ScanResult: Identifiable {
        case product(Product)
        case vitamin(VitaminInfo)

        var id: UUID {
            switch self {
            case .product(let product): return product.id
            case .vitamin(let vitamin): return vitamin.id
            }
        }
    }

    private var isScannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isScannerAvailable {
                    ScannerRepresentable { text in
                        handleScanned(text)
                    }
                    .ignoresSafeArea()
                } else {
                    unavailableState
                }

                VStack {
                    Spacer()
                    Text("Point the camera at a supplement label")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: Capsule())
                        .padding(.bottom, 40)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(.white)
                }
            }
            .sheet(item: $scannedResult) { result in
                ScanResultView(result: result)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func handleScanned(_ text: String) {
        guard scannedResult == nil else { return }
        if let product = appState.products.first(where: {
            text.localizedCaseInsensitiveContains($0.name) || text.localizedCaseInsensitiveContains($0.abbr)
        }) {
            scannedResult = .product(product)
        } else if let vitamin = VitaminDatabase.match(text: text) {
            scannedResult = .vitamin(vitamin)
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

/// Bridges VisionKit's DataScannerViewController (UIKit) into SwiftUI,
/// running live text recognition and reporting each recognized string.
private struct ScannerRepresentable: UIViewControllerRepresentable {
    var onTextRecognized: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextRecognized: onTextRecognized)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onTextRecognized: (String) -> Void

        init(onTextRecognized: @escaping (String) -> Void) {
            self.onTextRecognized = onTextRecognized
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .text(let text) = item {
                    onTextRecognized(text.transcript)
                }
            }
        }
    }
}

/// Shows what Scan found: name, short description, usage and
/// restrictions — from either the club's own product catalog or the
/// built-in vitamin reference.
private struct ScanResultView: View {
    let result: ScanView.ScanResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                infoRow("Usage", usageText)
                infoRow("Restrictions", restrictionsText)
                if let interactions = interactionsText {
                    infoRow("Interactions", interactions)
                }
            }
            .screenPadding()
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.brand(28))
                .foregroundStyle(.white)
            Text(description)
                .font(.system(size: 14))
                .foregroundStyle(Color.appTextSecondary)
                .lineSpacing(3)
        }
    }

    private func infoRow(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowLabel(text: title)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(padding: 14)
    }

    private var name: String {
        switch result {
        case .product(let product): return product.name
        case .vitamin(let vitamin): return vitamin.name
        }
    }

    private var description: String {
        switch result {
        case .product(let product): return product.desc
        case .vitamin(let vitamin): return vitamin.description
        }
    }

    private var usageText: String {
        switch result {
        case .product(let product): return "\(product.benefits)\n\nTypical dose: \(product.dose)"
        case .vitamin(let vitamin): return vitamin.usage
        }
    }

    private var restrictionsText: String {
        switch result {
        case .product(let product): return product.risks
        case .vitamin(let vitamin): return vitamin.restrictions
        }
    }

    private var interactionsText: String? {
        switch result {
        case .product(let product): return product.interactions
        case .vitamin: return nil
        }
    }
}

#Preview {
    ScanView()
        .environmentObject(AppState())
}
