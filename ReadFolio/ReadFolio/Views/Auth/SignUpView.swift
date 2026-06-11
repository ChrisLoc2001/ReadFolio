import SwiftUI
import GoogleSignInSwift

struct SignUpView: View {
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var email           = ""
    @State private var username        = ""
    @State private var password        = ""
    @State private var confirmPassword = ""
    @State private var isCheckingUsername = false
    @State private var usernameAvailable: Bool? = nil

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

                    // Username con feedback disponibilità
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            TextField("Nome Utente", text: $username)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .padding(12)
                                .background(.regularMaterial,
                                            in: RoundedRectangle(cornerRadius: 10))
                                .onChange(of: username) { _, newValue in
                                    checkUsernameAvailability(newValue)
                                }

                            if isCheckingUsername {
                                ProgressView()
                                    .padding(.trailing, 4)
                            } else if let available = usernameAvailable {
                                Image(systemName: available
                                      ? "checkmark.circle.fill"
                                      : "xmark.circle.fill")
                                .foregroundStyle(available ? .green : .red)
                                .padding(.trailing, 4)
                            }
                        }

                        if let available = usernameAvailable, !available {
                            Text("Nome utente non disponibile")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.leading, 4)
                        } else if let available = usernameAvailable, available {
                            Text("Nome utente disponibile")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .padding(.leading, 4)
                        }
                    }

                    SecureField("Password (min. 8 caratteri)", text: $password)
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
                if !password.isEmpty && password.count < 8 {
                    Text("La password deve avere almeno 8 caratteri")
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
                            email:           email,
                            password:        password,
                            confirmPassword: confirmPassword,
                            username:        username
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
                .disabled(isFormInvalid)

                divider

                // MARK: - Social buttons
                HStack(spacing: 16) {
                    GoogleSignInButton(scheme: .light, style: .icon, state: .normal) {
                        Task { await authVM.signInWithGoogle() }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(authVM.isLoading)

                    VStack(spacing: 4) {
                        Button {
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

                        Text("Presto")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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

    // MARK: - Helpers

    private var isFormInvalid: Bool {
        authVM.isLoading          ||
        password.count < 8        ||
        password != confirmPassword ||
        email.isEmpty             ||
        username.count < 3        ||
        usernameAvailable == false
    }

    private func checkUsernameAvailability(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else {
            usernameAvailable = nil
            return
        }
        isCheckingUsername = true
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard username == value else { return }
            usernameAvailable  = await authVM.isUsernameAvailable(trimmed)
            isCheckingUsername = false
        }
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
