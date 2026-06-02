import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var email           = ""
    @State private var password        = ""
    @State private var showResetAlert  = false

    var switchToSignUp: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                // MARK: - Campi
                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(12)
                        .background(.regularMaterial,
                                    in: RoundedRectangle(cornerRadius: 10))

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding(12)
                        .background(.regularMaterial,
                                    in: RoundedRectangle(cornerRadius: 10))
                }

                // MARK: - Errore
                if let error = authVM.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                // MARK: - Bottone login
                actionButton(title: "Accedi") {
                    Task { await authVM.login(email: email, password: password) }
                }

                Button("Password dimenticata?") {
                    showResetAlert = true
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                divider

                // MARK: - Google
                googleButton

                divider

                // MARK: - Switch
                HStack {
                    Text("Non hai un account?")
                        .foregroundStyle(.secondary)
                    Button("Registrati") { switchToSignUp() }
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
            }
            .padding(24)
        }
        .alert("Recupera password", isPresented: $showResetAlert) {
            TextField("Email", text: $email)
            Button("Invia") {
                Task { await authVM.resetPassword(email: email) }
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Riceverai un link per reimpostare la password.")
        }
    }

    // MARK: - Components

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 50))
                .foregroundStyle(.accentColor)
            Text("Readfolio")
                .font(.largeTitle.bold())
            Text("Accedi al tuo account")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
        .padding(.bottom, 8)
    }

    private var googleButton: some View {
        Button {
            Task { await authVM.signInWithGoogle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                Text("Continua con Google")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.primary)
        }
        .disabled(authVM.isLoading)
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if authVM.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
        }
        .disabled(authVM.isLoading)
    }

    private var divider: some View {
        HStack {
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(.secondary.opacity(0.4))
            Text("oppure")
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(.secondary.opacity(0.4))
        }
    }
}