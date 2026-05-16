import Foundation
import Observation
import SwiftData

// MARK: - DTOs (para vistas y reportes)

struct StudentProfile: Codable, Equatable, Identifiable {
    var id: String { email.lowercased() }
    var controlNumber: String
    var fullName: String
    var career: String
    var semester: Int
    var requiredServiceHours: Double
    var serviceLocation: String
    var email: String
    /// Inicio del ciclo actual de servicio (cada ~1.5 meses = 3 reportes).
    var serviceStartDate: Date

    static func empty(email: String) -> StudentProfile {
        StudentProfile(
            controlNumber: "",
            fullName: "",
            career: "",
            semester: 1,
            requiredServiceHours: 480,
            serviceLocation: "",
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            serviceStartDate: Date()
        )
    }
}

/// Resumen de un reporte parcial (1, 2 o 3) dentro del ciclo de mes y medio.
struct PartialServiceReport {
    let reportNumber: Int
    let cycleStart: Date
    let reportCutoff: Date
    let cumulativeHours: Double
    let sessions: [CompletedSession]
    let hoursByReport: [(number: Int, hours: Double, cutoff: Date)]
}

enum PunchKind: String, Codable {
    case entrada
    case salida
}

struct TimePunch: Codable, Identifiable {
    var id: UUID
    var date: Date
    var kind: PunchKind
    var qrPayload: String
}

struct PersistedAccount: Codable {
    var password: String
    var profile: StudentProfile
}

struct CompletedSession: Identifiable {
    let id: UUID
    var start: Date
    var end: Date
    var durationHours: Double
}

// MARK: - SwiftData (base de datos local)

@Model
final class BiblioUser {
    @Attribute(.unique) var email: String
    var password: String
    var controlNumber: String
    var fullName: String
    var career: String
    var semester: Int
    var requiredServiceHours: Double
    var serviceLocation: String
    var serviceStartDate: Date

    @Relationship(deleteRule: .cascade, inverse: \BiblioTimePunch.user)
    var punches: [BiblioTimePunch]

    init(
        email: String,
        password: String,
        controlNumber: String,
        fullName: String,
        career: String,
        semester: Int,
        requiredServiceHours: Double,
        serviceLocation: String,
        serviceStartDate: Date = Date()
    ) {
        self.email = email.lowercased()
        self.password = password
        self.controlNumber = controlNumber
        self.fullName = fullName
        self.career = career
        self.semester = semester
        self.requiredServiceHours = requiredServiceHours
        self.serviceLocation = serviceLocation
        self.serviceStartDate = serviceStartDate
        self.punches = []
    }
}

@Model
final class BiblioTimePunch {
    var id: UUID
    var date: Date
    var kindRaw: String
    var qrPayload: String
    var user: BiblioUser?

    init(id: UUID = UUID(), date: Date, kind: PunchKind, qrPayload: String, user: BiblioUser?) {
        self.id = id
        self.date = date
        self.kindRaw = kind.rawValue
        self.qrPayload = qrPayload
        self.user = user
    }

    var kind: PunchKind {
        PunchKind(rawValue: kindRaw) ?? .entrada
    }
}

// MARK: - Sesión

@Observable
@MainActor
final class AppSession {
    /// Días por reporte (3 reportes ≈ 45 días ≈ mes y medio).
    static let daysPerPartialReport = 15
    static let partialReportsPerCycle = 3

    private let legacyUsersKey = "bibliocheck.registeredUsers"
    private let accountsKey = "bibliocheck.userAccounts.v3"
    private let sessionKey = "bibliocheck.sessionEmail"
    private let migrationDoneKey = "bibliocheck.swiftdata.migrated.v1"

    let container: ModelContainer
    private let context: ModelContext

    private(set) var currentUserEmail: String?

    init() {
        do {
            let schema = Schema([BiblioUser.self, BiblioTimePunch.self])
            let created: ModelContainer
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                // Para previews, evita crear un store persistente (usa configuración por defecto).
                created = try ModelContainer(for: schema)
            } else {
                let config = ModelConfiguration("bibliocheck.store")
                created = try ModelContainer(for: schema, configurations: [config])
            }
            container = created
            context = ModelContext(created)
            context.autosaveEnabled = true
        } catch {
            fatalError("No se pudo iniciar la base de datos: \(error.localizedDescription)")
        }

        currentUserEmail = UserDefaults.standard.string(forKey: sessionKey)
        migrateFromPlistStorageIfNeeded()
    }

    var isLoggedIn: Bool { currentUserEmail != nil }

    func profile(for email: String) -> StudentProfile? {
        guard let u = fetchUser(email: email) else { return nil }
        return StudentProfile(
            controlNumber: u.controlNumber,
            fullName: u.fullName,
            career: u.career,
            semester: u.semester,
            requiredServiceHours: u.requiredServiceHours,
            serviceLocation: u.serviceLocation,
            email: u.email,
            serviceStartDate: u.serviceStartDate
        )
    }

    func serviceStartDate(for email: String) -> Date {
        fetchUser(email: email)?.serviceStartDate ?? Date()
    }

    func reportCutoffDate(cycleStart: Date, reportNumber: Int) -> Date {
        let days = reportNumber * Self.daysPerPartialReport
        return Calendar.current.date(byAdding: .day, value: days, to: cycleStart) ?? cycleStart
    }

    /// Horas acumuladas desde el inicio del ciclo hasta el corte del reporte (o hoy si es antes).
    func cumulativeHours(for email: String, reportNumber: Int) -> Double {
        partialReport(for: email, reportNumber: reportNumber).cumulativeHours
    }

    func partialReport(for email: String, reportNumber: Int) -> PartialServiceReport {
        let n = min(max(reportNumber, 1), Self.partialReportsPerCycle)
        let start = serviceStartDate(for: email)
        let cutoff = reportCutoffDate(cycleStart: start, reportNumber: n)
        let effectiveEnd = min(Date(), endOfDay(cutoff))
        let all = completedSessions(for: email)
        let inPeriod = all.filter { $0.end >= start && $0.end <= effectiveEnd }
        let hours = inPeriod.reduce(0) { $0 + $1.durationHours }

        var byReport: [(number: Int, hours: Double, cutoff: Date)] = []
        for i in 1...Self.partialReportsPerCycle {
            let cut = reportCutoffDate(cycleStart: start, reportNumber: i)
            let end = min(Date(), endOfDay(cut))
            let h = all.filter { $0.end >= start && $0.end <= end }.reduce(0) { $0 + $1.durationHours }
            byReport.append((i, h, cut))
        }

        return PartialServiceReport(
            reportNumber: n,
            cycleStart: start,
            reportCutoff: cutoff,
            cumulativeHours: hours,
            sessions: inPeriod,
            hoursByReport: byReport
        )
    }

    var currentProfile: StudentProfile? {
        guard let email = currentUserEmail else { return nil }
        return profile(for: email)
    }

    var displayFirstName: String {
        guard let email = currentUserEmail else { return "USUARIO" }
        if let name = profile(for: email)?.fullName.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name.split(separator: " ").first.map(String.init) ?? name
        }
        let local = email.split(separator: "@").first.map(String.init) ?? email
        return local.replacingOccurrences(of: ".", with: " ").capitalized
    }

    func signUp(profile: StudentProfile, password: String, logInAfter: Bool = true) -> String? {
        let key = profile.email.lowercased()
        guard !key.isEmpty, profile.email.contains("@") else { return "Correo no válido." }
        if fetchUser(email: key) != nil { return "Este correo ya está registrado." }

        let u = BiblioUser(
            email: key,
            password: password,
            controlNumber: profile.controlNumber,
            fullName: profile.fullName,
            career: profile.career,
            semester: profile.semester,
            requiredServiceHours: profile.requiredServiceHours,
            serviceLocation: profile.serviceLocation,
            serviceStartDate: profile.serviceStartDate
        )
        context.insert(u)
        do { try context.save() } catch { return "Error al guardar: \(error.localizedDescription)" }
        if logInAfter { setSession(email: key) }
        return nil
    }

    func login(email: String, password: String) -> String? {
        let key = email.lowercased()
        guard let u = fetchUser(email: key), u.password == password else {
            return "Correo o contraseña incorrectos."
        }
        setSession(email: key)
        return nil
    }

    func updateProfile(_ profile: StudentProfile) -> String? {
        guard let email = currentUserEmail else { return "No hay sesión." }
        let key = email.lowercased()
        guard let u = fetchUser(email: key) else { return "Cuenta no encontrada." }
        u.controlNumber = profile.controlNumber
        u.fullName = profile.fullName
        u.career = profile.career
        u.semester = profile.semester
        u.requiredServiceHours = profile.requiredServiceHours
        u.serviceLocation = profile.serviceLocation
        u.serviceStartDate = profile.serviceStartDate
        do { try context.save() } catch { return "Error al guardar: \(error.localizedDescription)" }
        return nil
    }

    func logout() {
        currentUserEmail = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    // MARK: - Fichajes / QR

    func punches(for email: String) -> [TimePunch] {
        guard let u = fetchUser(email: email) else { return [] }
        return u.punches
            .sorted { $0.date < $1.date }
            .map { TimePunch(id: $0.id, date: $0.date, kind: $0.kind, qrPayload: $0.qrPayload) }
    }

    func registerScan(qrPayload: String) -> (title: String, detail: String)? {
        guard let email = currentUserEmail, let u = fetchUser(email: email) else { return nil }
        let trimmed = qrPayload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("Sin datos", "El código no tiene texto legible.") }

        let sorted = u.punches.sorted { $0.date < $1.date }
        let next: PunchKind
        if let last = sorted.last {
            next = last.kind == .entrada ? .salida : .entrada
        } else {
            next = .entrada
        }

        let punch = BiblioTimePunch(date: Date(), kind: next, qrPayload: trimmed, user: u)
        context.insert(punch)
        u.punches.append(punch)
        do { try context.save() } catch {
            return ("Error", "No se pudo guardar el registro: \(error.localizedDescription)")
        }

        let punchDTO = TimePunch(id: punch.id, date: punch.date, kind: next, qrPayload: trimmed)
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_MX")
        df.dateStyle = .none
        df.timeStyle = .short

        if next == .entrada {
            return (
                "Entrada registrada",
                "Entrada a las \(df.string(from: punchDTO.date)). Al salir, vuelve a escanear el mismo código QR de la biblioteca."
            )
        }

        let sessions = completedSessions(for: email)
        guard let lastSession = sessions.last else {
            return (
                "Salida registrada",
                "Salida a las \(df.string(from: punchDTO.date)). Si falta una entrada previa, revisa el historial."
            )
        }
        let mins = Int((lastSession.durationHours * 60).rounded())
        let h = mins / 60
        let m = mins % 60
        let durText = h > 0 ? "\(h) h \(m) min" : "\(m) min"
        return (
            "Salida registrada",
            "Estuviste \(durText) en esta visita (salida \(df.string(from: punchDTO.date)))."
        )
    }

    func completedSessions(for email: String) -> [CompletedSession] {
        let list = punches(for: email)
        var result: [CompletedSession] = []
        var openEntry: Date?
        for p in list {
            switch p.kind {
            case .entrada:
                openEntry = p.date
            case .salida:
                if let start = openEntry {
                    let secs = p.date.timeIntervalSince(start)
                    let hours = secs / 3600
                    result.append(CompletedSession(id: UUID(), start: start, end: p.date, durationHours: hours))
                    openEntry = nil
                }
            }
        }
        return result
    }

    func totalRegisteredHours(for email: String) -> Double {
        completedSessions(for: email).reduce(0) { $0 + $1.durationHours }
    }

    func openEntryDate(for email: String) -> Date? {
        let list = punches(for: email)
        guard let last = list.last else { return nil }
        return last.kind == .entrada ? last.date : nil
    }

    func todayStatusMessage(for email: String) -> String {
        let cal = Calendar.current
        let list = punches(for: email).filter { cal.isDateInToday($0.date) }
        guard let last = list.last else {
            return "Hoy no has registrado entrada."
        }
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_MX")
        df.timeStyle = .short
        if last.kind == .entrada {
            return "Dentro de la biblioteca — entrada a las \(df.string(from: last.date)). Sal: escanea de nuevo el QR."
        }
        return "Fuera — última salida hoy a las \(df.string(from: last.date))."
    }

    // MARK: - Private

    private func fetchUser(email: String) -> BiblioUser? {
        let search = email.lowercased()
        let predicate = #Predicate<BiblioUser> { user in
            user.email == search
        }
        var descriptor = FetchDescriptor<BiblioUser>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func setSession(email: String) {
        currentUserEmail = email.lowercased()
        UserDefaults.standard.set(currentUserEmail, forKey: sessionKey)
    }

    private func punchesKey(_ email: String) -> String {
        "bibliocheck.punches.\(email.lowercased())"
    }

    private func endOfDay(_ date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
    }

    /// Migra datos antiguos de UserDefaults la primera vez que usas SwiftData.
    private func migrateFromPlistStorageIfNeeded() {
        if UserDefaults.standard.bool(forKey: migrationDoneKey) { return }

        var descriptor = FetchDescriptor<BiblioUser>()
        descriptor.fetchLimit = 1
        if (try? context.fetchCount(descriptor)) ?? 0 > 0 {
            UserDefaults.standard.set(true, forKey: migrationDoneKey)
            return
        }

        var accounts: [String: PersistedAccount]?
        if let data = UserDefaults.standard.data(forKey: accountsKey),
           let decoded = try? JSONDecoder().decode([String: PersistedAccount].self, from: data) {
            accounts = decoded
        } else if let legacy = UserDefaults.standard.dictionary(forKey: legacyUsersKey) as? [String: String],
                  !legacy.isEmpty {
            var map: [String: PersistedAccount] = [:]
            for (emailKey, pass) in legacy {
                let key = emailKey.lowercased()
                let profile = StudentProfile(
                    controlNumber: "—",
                    fullName: "Usuario",
                    career: "Completa tu perfil",
                    semester: 1,
                    requiredServiceHours: 480,
                    serviceLocation: "—",
                    email: key,
                    serviceStartDate: Date()
                )
                map[key] = PersistedAccount(password: pass, profile: profile)
            }
            accounts = map
        }

        guard let accMap = accounts else {
            UserDefaults.standard.set(true, forKey: migrationDoneKey)
            return
        }

        for (key, acc) in accMap {
            let p = acc.profile
            let u = BiblioUser(
                email: key,
                password: acc.password,
                controlNumber: p.controlNumber,
                fullName: p.fullName,
                career: p.career,
                semester: p.semester,
                requiredServiceHours: p.requiredServiceHours,
                serviceLocation: p.serviceLocation
            )
            context.insert(u)
            if let data = UserDefaults.standard.data(forKey: punchesKey(key)),
               let oldPunches = try? JSONDecoder().decode([TimePunch].self, from: data) {
                for op in oldPunches {
                    let tp = BiblioTimePunch(id: op.id, date: op.date, kind: op.kind, qrPayload: op.qrPayload, user: u)
                    context.insert(tp)
                    u.punches.append(tp)
                }
            }
        }

        try? context.save()
        UserDefaults.standard.removeObject(forKey: accountsKey)
        UserDefaults.standard.removeObject(forKey: legacyUsersKey)
        for k in UserDefaults.standard.dictionaryRepresentation().keys where k.hasPrefix("bibliocheck.punches.") {
            UserDefaults.standard.removeObject(forKey: k)
        }
        UserDefaults.standard.set(true, forKey: migrationDoneKey)
    }
}
