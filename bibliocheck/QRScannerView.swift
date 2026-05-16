import SwiftUI
import VisionKit
import UIKit

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    var onCode: (String) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerRepresentable(onCode: onCode) {
                        dismiss()
                    }
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    ContentUnavailableView(
                        "Cámara no disponible",
                        systemImage: "camera.fill",
                        description: Text("Este dispositivo no puede usar el escáner en vivo, o la cámara está en uso.")
                    )
                }
            }
            .navigationTitle("Escanear QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode, onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.qr, .ean8, .ean13, .code128, .code39, .pdf417, .aztec, .dataMatrix])
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        context.coordinator.scanner = vc

        Task { @MainActor in
            try? vc.startScanning()
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        weak var scanner: DataScannerViewController?
        let onCode: (String) -> Void
        let onDismiss: () -> Void
        private var didEmit = false

        init(onCode: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
            self.onCode = onCode
            self.onDismiss = onDismiss
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            emitIfBarcode(item, from: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                emitIfBarcode(item, from: dataScanner)
            }
        }

        private func emitIfBarcode(_ item: RecognizedItem, from dataScanner: DataScannerViewController) {
            guard !didEmit else { return }
            guard case .barcode(let barcode) = item else { return }
            guard let value = barcode.payloadStringValue, !value.isEmpty else { return }

            didEmit = true
            Task { @MainActor in
                dataScanner.stopScanning()
                onCode(value)
                onDismiss()
            }
        }
    }
}
