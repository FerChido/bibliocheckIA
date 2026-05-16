import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var controlNumber = ""
    @State private var fullName = ""
    @State private var career = ""
    @State private var semester = 1
    @State private var requiredHoursText = "480"
    @State private var serviceLocation = ""
    @State private var serviceStartDate = Date()
    @State private var alertMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Crear cuenta")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)

                Group {
                    sectionLabel("Acceso")
                    TextField("Correo institucional", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
#if canImport(UIKit)
                        .autocorrectionDisabled(true)
#endif
                    SecureField("Contraseña (mín. 6 caracteres)", text: $password)
                        .textFieldStyle(.roundedBorder)
                    SecureField("Confirmar contraseña", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                }

                Group {
                    sectionLabel("Datos para servicio / biblioteca")
                    TextField("Número de control o ID", text: $controlNumber)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                    TextField("Nombre completo", text: $fullName)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                    TextField("Carrera", text: $career)
                        .textFieldStyle(.roundedBorder)
                    Stepper(value: $semester, in: 1...20) {
                        Text("Semestre: \(semester)")
                    }
                    TextField("Horas totales a cumplir (ej. 480)", text: $requiredHoursText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                    TextField("Lugar donde realizarás el servicio (ej. Biblioteca central)", text: $serviceLocation, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                    DatePicker("Inicio del servicio (ciclo de 3 reportes)", selection: $serviceStartDate, displayedComponents: .date)
                }

                Button {
                    attemptRegister()
                } label: {
                    Text("REGISTRARSE")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Registro")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Registro", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }

    private func attemptRegister() {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !e.isEmpty, e.contains("@") else {
            alertMessage = "Introduce un correo válido."
            return
        }
        guard password.count >= 6 else {
            alertMessage = "La contraseña debe tener al menos 6 caracteres."
            return
        }
        guard password == confirmPassword else {
            alertMessage = "Las contraseñas no coinciden."
            return
        }
        let ctrl = controlNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let car = career.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = serviceLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ctrl.isEmpty, !name.isEmpty, !car.isEmpty, !place.isEmpty else {
            alertMessage = "Completa número de control, nombre, carrera y lugar de servicio."
            return
        }
        let hours = Double(requiredHoursText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard hours > 0 else {
            alertMessage = "Indica las horas totales a cumplir (un número mayor que 0)."
            return
        }

        let profile = StudentProfile(
            controlNumber: ctrl,
            fullName: name,
            career: car,
            semester: semester,
            requiredServiceHours: hours,
            serviceLocation: place,
            email: e.lowercased(),
            serviceStartDate: serviceStartDate
        )

        if let err = session.signUp(profile: profile, password: password, logInAfter: true) {
            alertMessage = err
        } else {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environment(AppSession())
    }
}
