import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var goToHome = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                
                // Fondo degradado
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    
                    Spacer()
                    
                    // Logo + título
                    VStack {
                        Image(systemName: "qrcode")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.white)
                        
                        Text("BiblioCheck")
                            .foregroundColor(.white)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("INICIA SESIÓN")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Campos
                    VStack(spacing: 15) {
                        
                        TextField("Correo electrónico", text: $email)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
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
                    
                    // Botón entrar
                    Button {
                        if !email.isEmpty && !password.isEmpty {
                            goToHome = true
                        }
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
                    
                    // Navegación a Home
                    NavigationLink("", destination: HomeView(), isActive: $goToHome)
                        .hidden()
                    
                    // Crear cuenta
                    NavigationLink("CREAR CUENTA", destination: RegisterView())
                        .font(.footnote)
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
            }
        }
    }
}
