import SwiftUI
import VisionKit
import UIKit

struct MainTabView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        TabView {
            HomeDashboardView()
                .tabItem {
                    Label("INICIO", systemImage: "house.fill")
                }

            AttendanceHistoryView()
                .tabItem {
                    Label("HISTORIAL", systemImage: "clock")
                }

            ProfileView()
                .tabItem {
                    Label("PERFIL", systemImage: "person")
                }
        }
        .tint(.blue)
    }
}

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

// MARK: - Historial

struct AttendanceHistoryView: View {
    @Environment(AppSession.self) private var session

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                if let email = session.currentUserEmail {
                    let completed = session.completedSessions(for: email)
                    if completed.isEmpty {
                        ContentUnavailableView(
                            "Sin visitas cerradas",
                            systemImage: "clock",
                            description: Text("Cuando registres entrada y salida con el QR, verás aquí cada visita y sus horas.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        Section("Visitas completas") {
                            ForEach(completed) { s in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(Self.df.string(from: s.start)) → \(Self.df.string(from: s.end))")
                                        .font(.subheadline)
                                    Text(String(format: "%.2f h en biblioteca", s.durationHours))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    if let open = session.openEntryDate(for: email) {
                        Section {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Entrada sin salida aún")
                                        .font(.headline)
                                    Text("Desde \(Self.df.string(from: open)) — escanea el QR al salir.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "door.left.hand.open")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Historial")
        }
    }
}

// MARK: - Perfil

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
                    Section("Datos") {
                        LabeledContent("Correo", value: email)
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

                    Section("Reportes parciales (cada mes y medio)") {
                        Text("Tu universidad pide 3 reportes por ciclo. Cada uno lleva las horas **acumuladas** desde el inicio del ciclo hasta la fecha de entrega.")
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
                    }

                    Section("Exportar PDF para firma") {
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
                            Text("Cerrar sesión")
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

// MARK: - PDF reporte (inline para que compile aunque el .swift aparte no esté en el target)

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
            .appendingPathComponent("BiblioCheck_reporte\(partialReport.reportNumber)_\(profile.controlNumber.replacingOccurrences(of: "/", with: "-")).pdf")
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

// MARK: - Share (PDF)

private struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
#Preview("Tabs") {
    MainTabView()
        .environment(AppSession())
}

#Preview("Inicio") {
    HomeDashboardView()
        .environment(AppSession())
}
#endif
