import SwiftUI

// MARK: - Historial

struct AttendanceHistoryView: View {
    @EnvironmentObject private var session: AppSession

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
