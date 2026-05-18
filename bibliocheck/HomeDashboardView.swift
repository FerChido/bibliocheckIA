import SwiftUI
import VisionKit
import UIKit

// MARK: - Inicio

struct HomeDashboardView: View {
    @EnvironmentObject private var session: AppSession
    private let blue = Color.blue
    @State private var showScanner = false
    @State private var lastScannedCode: String?
    @State private var scanFeedback: (title: String, message: String)?
    @State private var showMenu = false
    @State private var showHelp = false
    @State private var showAbout = false

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button {
                    showMenu = true
                } label: {
                    Image(systemName: "line.horizontal.3")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                Spacer()

                Image(systemName: "person.crop.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
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
            QRScannerView(onCode: { code in
                lastScannedCode = code
            })
        }
        .alert(scanFeedback?.title ?? "", isPresented: Binding(
            get: { scanFeedback != nil },
            set: { if !$0 { scanFeedback = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(scanFeedback?.message ?? "")
        }
        .confirmationDialog("Menú", isPresented: $showMenu, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) {
                session.logout()
            }
            Button("Ayuda") {
                showHelp = true
            }
            Button("Acerca de") {
                showAbout = true
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Opciones rápidas de la aplicación")
        }
        .alert("Ayuda", isPresented: $showHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Aquí puedes ver cómo usar la app y resolver dudas básicas.")
        }
        .alert("Acerca de", isPresented: $showAbout) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("BiblioCheck — gestión de entradas y salidas para servicio social.")
        }
    }

    private func formatHours(_ h: Double) -> String {
        String(format: "%.1f", h)
    }
}

// QRScannerView y su representable se definen en QRScannerView.swift

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

#if DEBUG
#Preview("Inicio") {
    HomeDashboardView()
        .environmentObject(AppSession())
}
#endif
