import SwiftUI
import GoogleSignInSwift
import AuthenticationServices

struct SignUpView: View {
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var email           = ""
    @State private var password        = ""
    @State private var confirmPassword = ""

    var switchToLogin: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Header
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.accentColor)
                    Text("Crea account")
                        .font(.largeTitle.bold())
                    Text("Inizia a tracciare le tue letture")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 8)

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

                    SecureField("Password (min. 6 caratteri)", text: $password)
                        .textContentType(.newPassword)
                        .padding(12)
                        .background(.regularMaterial,
                                    in: RoundedRectangle(cornerRadius: 10))

                    SecureField("Conferma password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .padding(12)
                        .background(.regularMaterial,
                                    in: RoundedRectangle(cornerRadius: 10))
                }

                // MARK: - Validation hints
                if !password.isEmpty && password.count < 6 {
                    Text("La password deve avere almeno 6 caratteri")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if !confirmPassword.isEmpty && password != confirmPassword {
                    Text("Le password non coincidono")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                // MARK: - Errore
                if let error = authVM.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                // MARK: - Bottone registrazione
                Button {
                    Task {
                        await authVM.signUp(
                            email: email,
                            password: password,
                            confirmPassword: confirmPassword
                        )
                    }
                } label: {
                    Group {
                        if authVM.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Registrati").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color.accentColor,
                                in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .disabled(
                    authVM.isLoading ||
                    password.count < 6 ||
                    password != confirmPassword ||
                    email.isEmpty
                )

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
                    Text("Hai già un account?")
                        .foregroundStyle(.secondary)
                    Button("Accedi") { switchToLogin() }
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.bottom, 24)
            }
            .padding(24)
        }
    }

    // MARK: - Divider

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
