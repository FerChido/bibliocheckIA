import SwiftUI

struct LoginView: View {
    @Environment(AppSession.self) private var session
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var alertMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
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
                    }

                    Text("INICIA SESIÓN")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    VStack(spacing: 15) {
                        TextField("Correo electrónico", text: $email)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
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
                        .background(Color.white)
                        .cornerRadius(10)
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
                            .background(Color.blue)
                            .cornerRadius(25)
                    }
                    .padding(.horizontal, 50)

                    NavigationLink("CREAR CUENTA") {
                        RegisterView()
                    }
                    .font(.footnote)
                    .foregroundColor(.blue)

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
    LoginView()
        .environment(AppSession())
}
