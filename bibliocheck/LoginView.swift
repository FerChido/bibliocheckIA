import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AppSession
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var alertMessage: String?

    var body: some View {
        NavigationStack {
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
                        Image(systemName: "qrcode")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.white)

                        Text("BiblioCheck")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Gestión de servicio social")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Text("INICIA SESIÓN")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    VStack(spacing: 15) {
                        TextField("Correo electrónico", text: $email)
                            .padding()
                            .background(Color.white.opacity(0.95))
                            .cornerRadius(12)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
#if canImport(UIKit)
                            .autocorrectionDisabled(true)
#endif

                        HStack {
                            if showPassword {
                                TextField("Contraseña", text: $password)
                            } else {
                                SecureField("Contraseña", text: $password)
                            }

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.95))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 30)

                    Button {
                        attemptLogin()
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

                    VStack(spacing: 10) {
                        NavigationLink("CREAR CUENTA") {
                            RegisterView()
                        }
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.9))
                        .fontWeight(.semibold)

                        NavigationLink("ACCESO ADMIN") {
                            AdminView()
                        }
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.9))
                        .fontWeight(.semibold)
                    }

                    Spacer()
                }
            }
            .alert("No se pudo iniciar sesión", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func attemptLogin() {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password
        guard !e.isEmpty, !p.isEmpty else {
            alertMessage = "Completa correo y contraseña."
            return
        }
        guard e.contains("@") else {
            alertMessage = "Introduce un correo válido."
            return
        }
        if let err = session.login(email: e, password: p) {
            alertMessage = err
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AppSession())
    }
}
