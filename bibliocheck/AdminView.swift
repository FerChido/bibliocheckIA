import SwiftUI

struct AdminView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    
    @State private var adminPassword = ""
    @State private var isAuthenticated = false
    @State private var authError: String?
    @State private var selectedUser: StudentProfile?

    var body: some View {
        NavigationStack {
            if isAuthenticated {
                AdminDashboardView(selectedUser: $selectedUser)
                    .environmentObject(session)
                    .navigationTitle("Panel Admin")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cerrar") {
                                dismiss()
                            }
                        }
                    }
            } else {
                AdminLoginView(
                    password: $adminPassword,
                    isAuthenticated: $isAuthenticated,
                    authError: $authError
                )
            }
        }
    }
}

struct AdminLoginView: View {
    @Binding var password: String
    @Binding var isAuthenticated: Bool
    @Binding var authError: String?
    
    let ADMIN_PASSWORD = "admin2024" // Cambia esto a una contraseña segura

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.05, green: 0.25, blue: 0.6), Color(red: 0.1, green: 0.4, blue: 0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.white)

                    Text("ACCESO ADMIN")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Panel de administración")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                VStack(spacing: 15) {
                    SecureField("Contraseña de administrador", text: $password)
                        .padding()
                        .background(Color.white.opacity(0.95))
                        .cornerRadius(12)
                        .font(.system(size: 16))
                }
                .padding(.horizontal, 30)

                Button {
                    attemptAdminLogin()
                } label: {
                    Text("ENTRAR")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.0, green: 0.15, blue: 0.5))
                        .cornerRadius(25)
                }
                .padding(.horizontal, 50)

                if let error = authError {
                    Text(error)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                        .font(.caption)
                        .padding(10)
                        .background(Color(red: 0.8, green: 0.2, blue: 0.2).opacity(0.8))
                        .cornerRadius(8)
                        .padding(.horizontal, 30)
                }

                Spacer()
            }
        }
    }

    private func attemptAdminLogin() {
        if password == ADMIN_PASSWORD {
            isAuthenticated = true
            authError = nil
        } else {
            authError = "Contraseña incorrecta"
            password = ""
        }
    }
}

struct AdminDashboardView: View {
    @EnvironmentObject private var session: AppSession
    @Binding var selectedUser: StudentProfile?
    @State private var users: [StudentProfile] = []

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.9, green: 0.95, blue: 1.0), Color.white]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            NavigationStack {
                List {
                    Section(header: HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(Color(red: 0.05, green: 0.25, blue: 0.6))
                        Text("Usuarios Registrados (\(users.count))")
                            .foregroundColor(Color(red: 0.05, green: 0.25, blue: 0.6))
                    }) {
                        if users.isEmpty {
                            HStack {
                                Image(systemName: "person.slash")
                                    .foregroundColor(Color(red: 0.1, green: 0.4, blue: 0.8))
                                Text("No hay usuarios registrados")
                                    .foregroundColor(Color(red: 0.1, green: 0.4, blue: 0.8))
                            }
                        } else {
                            ForEach(users) { user in
                                NavigationLink {
                                    AdminUserDetailView(user: user)
                                        .environmentObject(session)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(user.fullName)
                                            .fontWeight(.semibold)
                                            .foregroundColor(Color(red: 0.05, green: 0.25, blue: 0.6))
                                        Text(user.email)
                                            .font(.caption)
                                            .foregroundColor(Color(red: 0.1, green: 0.4, blue: 0.8))
                                        Text("Control: \(user.controlNumber)")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .listStyle(.grouped)
                .scrollContentBackground(.hidden)
                .navigationTitle("Estudiantes")
                .navigationBarTitleDisplayMode(.large)
                .toolbarTitleMenu {}
            }
        }
        .onAppear {
            users = session.allUsers()
        }
    }
}

struct AdminUserDetailView: View {
    @EnvironmentObject private var session: AppSession
    let user: StudentProfile
    @State private var details: (profile: StudentProfile, punchesCount: Int, totalHours: Double)?

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.9, green: 0.95, blue: 1.0), Color.white]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            List {
                Section(header: HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(Color(red: 0.05, green: 0.25, blue: 0.6))
                    Text("Información Personal")
                        .foregroundColor(Color(red: 0.05, green: 0.25, blue: 0.6))
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "Nombre", value: user.fullName)
                        Divider().padding(.vertical, 4)
                        DetailRow(label: "Email", value: user.email)
                        Divider().padding(.vertical, 4)
                        DetailRow(label: "Control", value: user.controlNumber)
                        Divider().padding(.vertical, 4)
                        DetailRow(label: "Carrera", value: user.career)
                        Divider().padding(.vertical, 4)
                        DetailRow(label: "Semestre", value: "\(user.semester)")
                    }
                }

                Section(header: HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(Color(red: 0.05, green: 0.25, blue: 0.6))
                    Text("Servicio Social")
                        .foregroundColor(Color(red: 0.05, green: 0.25, blue: 0.6))
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "Lugar", value: user.serviceLocation)
                        Divider().padding(.vertical, 4)
                        DetailRow(label: "Horas requeridas", value: String(format: "%.1f h", user.requiredServiceHours))
                        if let details = details {
                            Divider().padding(.vertical, 4)
                            DetailRow(label: "Horas registradas", value: String(format: "%.1f h", details.totalHours), isBold: true)
                            Divider().padding(.vertical, 4)
                            let percentage = (details.totalHours / user.requiredServiceHours) * 100
                            ProgressRow(label: "Avance", value: String(format: "%.1f%%", percentage), percentage: percentage)
                        }
                    }
                }

                Section(header: HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(red: 0.05, green: 0.25, blue: 0.6))
                    Text("Actividad")
                        .foregroundColor(Color(red: 0.05, green: 0.25, blue: 0.6))
                }) {
                    if let details = details {
                        VStack(alignment: .leading, spacing: 12) {
                            DetailRow(label: "Fichajes totales", value: "\(details.punchesCount)")
                            Divider().padding(.vertical, 4)
                            DetailRow(label: "Sesiones completadas", value: "\(session.completedSessions(for: user.email).count)")
                        }
                    } else {
                        Text("Cargando...")
                            .foregroundColor(Color(red: 0.1, green: 0.4, blue: 0.8))
                    }
                }
            }
            .listStyle(.grouped)
            .scrollContentBackground(.hidden)
            .navigationTitle(user.fullName)
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            details = session.userDetails(email: user.email)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var isBold: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(Color(red: 0.05, green: 0.25, blue: 0.6))
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .foregroundColor(Color(red: 0.1, green: 0.4, blue: 0.8))
                .fontWeight(isBold ? .bold : .regular)
        }
        .font(.system(size: 15))
    }
}

struct ProgressRow: View {
    let label: String
    let value: String
    let percentage: Double
    
    var progressColor: Color {
        if percentage >= 100 {
            return Color(red: 0.0, green: 0.6, blue: 0.2)
        } else if percentage >= 75 {
            return Color(red: 0.05, green: 0.25, blue: 0.6)
        } else if percentage >= 50 {
            return Color(red: 0.1, green: 0.4, blue: 0.8)
        } else {
            return Color(red: 0.8, green: 0.4, blue: 0.0)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .foregroundColor(Color(red: 0.05, green: 0.25, blue: 0.6))
                    .fontWeight(.semibold)
                Spacer()
                Text(value)
                    .foregroundColor(progressColor)
                    .fontWeight(.bold)
            }
            ProgressView(value: percentage / 100.0)
                .tint(progressColor)
                .scaleEffect(y: 1.5, anchor: .center)
        }
        .font(.system(size: 15))
    }
}

#Preview {
    AdminView()
        .environmentObject(AppSession())
}
