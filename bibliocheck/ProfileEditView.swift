import SwiftUI
import UIKit

struct EditProfileView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var controlNumber = ""
    @State private var fullName = ""
    @State private var career = ""
    @State private var semester = 1
    @State private var requiredHoursText = ""
    @State private var serviceLocation = ""
    @State private var serviceStartDate = Date()
    @State private var alertMessage: String?

    var body: some View {
        Form {
            Section("Datos") {
                TextField("Número de control o ID", text: $controlNumber)
                TextField("Nombre completo", text: $fullName)
                TextField("Carrera", text: $career)
                Stepper(value: $semester, in: 1...20) {
                    Text("Semestre: \(semester)")
                }
                TextField("Horas totales a cumplir", text: $requiredHoursText)
                    .keyboardType(.decimalPad)
                TextField("Lugar de servicio", text: $serviceLocation, axis: .vertical)
                    .lineLimit(2...4)
            }
            Section("Ciclo de reportes") {
                DatePicker("Inicio del servicio / ciclo", selection: $serviceStartDate, displayedComponents: .date)
                Text("A partir de esta fecha se calculan los 3 reportes (cada ~15 días, ciclo de mes y medio).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Guardar") { save() }
                    .fontWeight(.semibold)
            }
        }
        .navigationTitle("Editar perfil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { dismiss() }
            }
        }
        .onAppear {
            guard let email = session.currentUserEmail, let p = session.profile(for: email) else { return }
            controlNumber = p.controlNumber
            fullName = p.fullName
            career = p.career
            semester = p.semester
            requiredHoursText = String(format: "%.0f", p.requiredServiceHours)
            serviceLocation = p.serviceLocation
            serviceStartDate = p.serviceStartDate
        }
        .alert("Perfil", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func save() {
        guard let email = session.currentUserEmail else { return }
        let ctrl = controlNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let car = career.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = serviceLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ctrl.isEmpty, !name.isEmpty, !car.isEmpty, !place.isEmpty else {
            alertMessage = "Completa todos los campos."
            return
        }
        let hours = Double(requiredHoursText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard hours > 0 else {
            alertMessage = "Las horas deben ser un número mayor que 0."
            return
        }
        let profile = StudentProfile(
            controlNumber: ctrl,
            fullName: name,
            career: car,
            semester: semester,
            requiredServiceHours: hours,
            serviceLocation: place,
            email: email.lowercased(),
            serviceStartDate: serviceStartDate
        )
        if let err = session.updateProfile(profile) {
            alertMessage = err
        } else {
            dismiss()
        }
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
