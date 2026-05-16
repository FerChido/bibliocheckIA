import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(AppSession.self) private var session
    @State private var showEdit = false
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var showReportPicker = false

    private static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                if let email = session.currentUserEmail, let p = session.profile(for: email) {
                    Section {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 56, height: 56)
                                Text(p.fullName.split(separator: " ").first.map(String.init)?.prefix(1) ?? "U")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.fullName)
                                    .font(.headline)
                                Text("Perfil registrado")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                Button {
                                    showEdit = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.borderless)

                                let done = session.totalRegisteredHours(for: email)
                                Text(String(format: "%.0f h", done))
                                    .font(.caption2)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Capsule().fill(Color.blue.opacity(0.12)))
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Section(header: Label("Datos de registro", systemImage: "person.crop.circle")) {
                        LabeledContent("Control / ID", value: p.controlNumber)
                        LabeledContent("Nombre", value: p.fullName)
                        LabeledContent("Carrera", value: p.career)
                        LabeledContent("Semestre", value: "\(p.semester)")
                        LabeledContent("Lugar de servicio", value: p.serviceLocation)
                        LabeledContent("Meta de horas", value: String(format: "%.0f h", p.requiredServiceHours))
                        let hechas = session.totalRegisteredHours(for: email)
                        LabeledContent("Horas registradas", value: String(format: "%.2f h", hechas))
                        LabeledContent("Inicio del ciclo") {
                            Text(Self.dateOnly.string(from: p.serviceStartDate))
                        }
                    }

                    Section(header: Label("Reportes parciales (cada mes y medio)", systemImage: "doc.text")) {
                        Text("Tu universidad pide 3 reportes por ciclo. Cada uno lleva las horas acumuladas desde el inicio del ciclo hasta la fecha de entrega.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(1...AppSession.partialReportsPerCycle, id: \.self) { n in
                            let snap = session.partialReport(for: email, reportNumber: n)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Reporte \(n) de 3")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Entrega sugerida: \(Self.dateOnly.string(from: snap.reportCutoff))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Horas acumuladas: \(String(format: "%.2f", snap.cumulativeHours)) h")
                                    .font(.caption)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Section {
                        Button("Editar mis datos") {
                            showEdit = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }

                    Section(header: Label("Exportar PDF para firma", systemImage: "square.and.arrow.up.on.square")) {
                        Button {
                            showReportPicker = true
                        } label: {
                            Label("Descargar reporte parcial (PDF)", systemImage: "doc.text")
                        }
                        Text("Elige reporte 1, 2 o 3. El PDF incluye tus horas acumuladas y el resumen de los tres entregables.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .confirmationDialog("¿Qué reporte vas a entregar?", isPresented: $showReportPicker, titleVisibility: .visible) {
                        ForEach(1...AppSession.partialReportsPerCycle, id: \.self) { n in
                            Button("Reporte \(n) de 3") {
                                exportPDF(email: email, profile: p, reportNumber: n)
                            }
                        }
                        Button("Cancelar", role: .cancel) {}
                    }

                    Section {
                        Button(role: .destructive) {
                            session.logout()
                        } label: {
                            Label("Cerrar sesión", systemImage: "power")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle("Perfil")
            .sheet(isPresented: $showEdit) {
                NavigationStack {
                    EditProfileView()
                        .environment(session)
                }
            }
            .sheet(isPresented: $showShareSheet, onDismiss: { shareURL = nil }) {
                if let url = shareURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    private func exportPDF(email: String, profile: StudentProfile, reportNumber: Int) {
        let partial = session.partialReport(for: email, reportNumber: reportNumber)
        shareURL = ServiceReportBuilder.makePDFReport(
            profile: profile,
            partialReport: partial,
            openEntry: session.openEntryDate(for: email)
        )
        showShareSheet = shareURL != nil
    }
}

private enum ServiceReportBuilder {
    static func makePDFReport(
        profile: StudentProfile,
        partialReport: PartialServiceReport,
        openEntry: Date?
    ) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "es_MX")
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let dateOnly = DateFormatter()
        dateOnly.locale = Locale(identifier: "es_MX")
        dateOnly.dateStyle = .medium
        dateOnly.timeStyle = .none

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 48
            let left: CGFloat = 48
            let titleFont = UIFont.boldSystemFont(ofSize: 18)
            let bodyFont = UIFont.systemFont(ofSize: 12)
            let small = UIFont.systemFont(ofSize: 10)

            func draw(_ text: String, font: UIFont, x: CGFloat, lineSpacing: CGFloat = 18) {
                let attr: [NSAttributedString.Key: Any] = [.font: font]
                text.draw(at: CGPoint(x: x, y: y), withAttributes: attr)
                y += lineSpacing
            }

            let n = partialReport.reportNumber
            draw("BiblioCheck — REPORTE PARCIAL \(n) DE 3", font: titleFont, x: left, lineSpacing: 28)
            draw("Ciclo de servicio (mes y medio): \(dateOnly.string(from: partialReport.cycleStart)) al \(dateOnly.string(from: partialReport.reportCutoff))", font: small, x: left, lineSpacing: 22)
            draw("Para validación y firma de encargado(a) o jefe(a) de área.", font: small, x: left, lineSpacing: 22)

            draw("Nombre: \(profile.fullName)", font: bodyFont, x: left)
            draw("No. de control / ID: \(profile.controlNumber)", font: bodyFont, x: left)
            draw("Correo: \(profile.email)", font: bodyFont, x: left)
            draw("Carrera: \(profile.career)", font: bodyFont, x: left)
            draw("Semestre: \(profile.semester)", font: bodyFont, x: left)
            draw("Lugar de servicio: \(profile.serviceLocation)", font: bodyFont, x: left)
            draw("Horas meta del servicio: \(Self.formatHours(profile.requiredServiceHours))", font: bodyFont, x: left)
            y += 6

            draw("HORAS ACUMULADAS EN ESTE REPORTE \(n): \(Self.formatHours(partialReport.cumulativeHours)) h", font: UIFont.boldSystemFont(ofSize: 13), x: left, lineSpacing: 22)
            draw("(Suma de todas las visitas desde el inicio del ciclo hasta la fecha de este entregable.)", font: small, x: left, lineSpacing: 20)

            draw("Resumen de los 3 reportes del ciclo:", font: UIFont.boldSystemFont(ofSize: 12), x: left, lineSpacing: 18)
            for item in partialReport.hoursByReport {
                draw("  • Reporte \(item.number): \(Self.formatHours(item.hours)) h acumuladas (corte \(dateOnly.string(from: item.cutoff)))", font: bodyFont, x: left)
            }
            y += 8

            draw("Detalle de visitas incluidas en el reporte \(n)", font: UIFont.boldSystemFont(ofSize: 14), x: left, lineSpacing: 20)

            if partialReport.sessions.isEmpty {
                draw("Aún no hay visitas cerradas en este periodo.", font: bodyFont, x: left)
            } else {
                for (idx, s) in partialReport.sessions.enumerated() {
                    let line = "\(idx + 1). \(dateFormatter.string(from: s.start)) → \(dateFormatter.string(from: s.end))  (\(Self.formatHours(s.durationHours)) h)"
                    draw(line, font: bodyFont, x: left)
                    if y > pageRect.height - 100 {
                        ctx.beginPage()
                        y = 48
                    }
                }
            }

            if let open = openEntry {
                y += 6
                draw("Nota: Hay una entrada abierta desde \(dateFormatter.string(from: open)) (sin salida escaneada aún).", font: small, x: left, lineSpacing: 14)
            }

            y = max(y, pageRect.height - 120)
            draw(String(repeating: "_", count: 40), font: bodyFont, x: left, lineSpacing: 28)
            draw("Nombre y firma del encargado", font: small, x: left)
            draw("Fecha: _______________", font: small, x: left)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BiblioCheck_reporte\(partialReport.reportNumber)_\(profile.controlNumber.replacingOccurrences(of: "/", with: "-" )).pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private static func formatHours(_ h: Double) -> String {
        String(format: "%.2f", h)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
