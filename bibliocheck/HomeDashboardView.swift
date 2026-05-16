import SwiftUI
import VisionKit
import UIKit

// MARK: - Inicio

struct HomeDashboardView: View {
    @Environment(AppSession.self) private var session
    private let blue = Color.blue
    @State private var showScanner = false
    @State private var lastScannedCode: String?
    @State private var scanFeedback: (title: String, message: String)?

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Image(systemName: "line.horizontal.3")
                    .font(.title2)

                Spacer()

                Image(systemName: "house.fill")
                    .font(.title3)
            }
            .padding(.horizontal)
            .foregroundColor(.blue)
            .padding(.top, 10)

            HStack {
                Text("HOLA, \(session.displayFirstName.uppercased())")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)

                Spacer()
            }
            .padding(.horizontal)

            if let email = session.currentUserEmail, let profile = session.profile(for: email) {
                let done = session.totalRegisteredHours(for: email)
                let goal = max(profile.requiredServiceHours, 1)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Avance de horas de servicio")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: min(done / goal, 1)) {
                        HStack {
                            Text("\(formatHours(done)) / \(formatHours(goal)) h")
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .tint(.blue)
                }
                .padding(.horizontal)
            }

            VStack(spacing: 10) {
                Text("ESTADO DE HOY")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))

                Text(session.currentUserEmail.map { session.todayStatusMessage(for: $0) } ?? "—")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(blue)
            .cornerRadius(18)
            .padding(.horizontal)

            Text("Mismo QR de la biblioteca: **1.ª vez = entrada**, **2.ª vez = salida**, y así alterna.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showScanner = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 28))

                    Text("ESCANEAR QR")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(blue)
                .cornerRadius(20)
                .shadow(color: .blue.opacity(0.25), radius: 6)
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                QuickAction(icon: "arrow.right.square", title: "ENTRADA")
                QuickAction(icon: "arrow.left.square", title: "SALIDA")
                QuickAction(icon: "clock", title: "HISTORIAL")
            }
            .padding(.horizontal)

            Spacer()
        }
        .background(Color.white.ignoresSafeArea())
        .sheet(isPresented: $showScanner, onDismiss: {
            if let code = lastScannedCode {
                if let feedback = session.registerScan(qrPayload: code) {
                    scanFeedback = (feedback.title, feedback.detail)
                }
                lastScannedCode = nil
            }
        }) {
            QRScannerView { code in
                lastScannedCode = code
            }
        }
        .alert(scanFeedback?.title ?? "", isPresented: Binding(
            get: { scanFeedback != nil },
            set: { if !$0 { scanFeedback = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(scanFeedback?.message ?? "")
        }
    }

    private func formatHours(_ h: Double) -> String {
        String(format: "%.1f", h)
    }
}

// MARK: - Quick action

struct QuickAction: View {
    var icon: String
    var title: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)

            Text(title)
                .font(.caption2)
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }
}

// MARK: - Escáner QR

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

#if DEBUG
#Preview("Inicio") {
    HomeDashboardView()
        .environment(AppSession())
}
#endif
