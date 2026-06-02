import SwiftUI
import GoogleSignInSwift
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var email          = ""
    @State private var password       = ""
    @State private var showResetAlert = false

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
                Button {
                    Task { await authVM.login(email: email, password: password) }
                } label: {
                    Group {
                        if authVM.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Accedi").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color.accentColor,
                                in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .disabled(authVM.isLoading)

                Button("Password dimenticata?") {
                    showResetAlert = true
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                divider

                // MARK: - Social buttons
                HStack(spacing: 16) {
                    // Google — solo icona
                    GoogleSignInButton(scheme: .light, style: .icon, state: .normal) {
                        Task { await authVM.signInWithGoogle() }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(authVM.isLoading)

                    // Apple — pulsante custom solo icona
                    Button {
                        // disponibile prossimamente
                    } label: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                    }
                    .disabled(true)
                    .opacity(0.4)
                }
                .frame(maxWidth: .infinity)

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
                .foregroundStyle(Color.accentColor)
            Text("Readfolio")
                .font(.largeTitle.bold())
            Text("Accedi al tuo account")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
        .padding(.bottom, 8)
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
