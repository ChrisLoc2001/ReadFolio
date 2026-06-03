import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - State
    @Published var isAuthenticated: Bool   = false
    @Published var isCheckingAuth:  Bool   = true
    @Published var isLoading:       Bool   = false
    @Published var errorMessage:    String?
    @Published var currentUser:     User?
    @Published var username:        String = ""
    /// True quando l'utente è autenticato ma non ha ancora completato la scelta
    /// di privacy del profilo (primo accesso o account creato prima del social).
    @Published var needsProfileSetup: Bool = false

    private let db     = Firestore.firestore()
    private let social = SocialRepository()

    // MARK: - Init
    init() {
        checkAuthState()
    }

    // MARK: - Auth state listener
    private func checkAuthState() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.currentUser     = user
                self.isAuthenticated = user != nil
                self.isCheckingAuth  = false
                if let user {
                    await self.refreshProfileState(userID: user.uid)
                }
            }
        }
    }

    // MARK: - Fetch username
    func fetchUsername(userID: String) async {
        do {
            let doc = try await db
                .collection("users")
                .document(userID)
                .collection("profile")
                .document("info")
                .getDocument()
            username = doc.data()?["username"] as? String ?? ""
        } catch {
            username = ""
        }
    }

    // MARK: - Stato profilo (username + setup privacy)
    /// Carica lo username e determina se serve completare il setup del profilo
    /// (assenza del profilo pubblico = privacy non ancora scelta).
    func refreshProfileState(userID: String) async {
        await fetchUsername(userID: userID)
        let profile = try? await social.myPublicProfile()
        needsProfileSetup = (profile == nil)
    }

    /// Completa il setup del profilo: riserva lo username se mancante (es. accesso
    /// con Google) e crea il profilo pubblico con le preferenze di privacy.
    /// Ritorna true se il setup è andato a buon fine.
    func completeProfileSetup(username chosen: String,
                              displayName: String,
                              isPublic: Bool,
                              followApprovalRequired: Bool) async -> Bool {
        guard let uid = currentUser?.uid else { return false }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var finalUsername = username
            if finalUsername.isEmpty {
                let trimmed = chosen.trimmingCharacters(in: .whitespaces).lowercased()
                guard trimmed.count >= 3 else {
                    errorMessage = "Il nome utente deve avere almeno 3 caratteri."
                    return false
                }
                guard await isUsernameAvailable(trimmed) else {
                    errorMessage = "Nome utente già in uso. Scegline un altro."
                    return false
                }
                try await saveUsername(trimmed, userID: uid)
                finalUsername = trimmed
            }

            try await social.upsertMyPublicProfile(
                username:               finalUsername,
                displayName:            displayName.trimmingCharacters(in: .whitespaces),
                isPublic:               isPublic,
                followApprovalRequired: followApprovalRequired
            )
            needsProfileSetup = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Verifica unicità username
    func isUsernameAvailable(_ username: String) async -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return false }
        let doc = try? await db
            .collection("usernames")
            .document(trimmed)
            .getDocument()
        return !(doc?.exists ?? false)
    }

    // MARK: - Salva username su Firestore
    private func saveUsername(_ username: String, userID: String) async throws {
        let trimmed = username.trimmingCharacters(in: .whitespaces).lowercased()

        // Salva nella collezione usernames per garantire unicità
        try await db.collection("usernames").document(trimmed).setData([
            "userID": userID
        ])

        // Salva nel profilo utente
        try await db
            .collection("users")
            .document(userID)
            .collection("profile")
            .document("info")
            .setData([
                "username": trimmed,
                "email":    Auth.auth().currentUser?.email ?? ""
            ])

        self.username = trimmed
    }

    // MARK: - Sign Up
    func signUp(email: String, password: String, confirmPassword: String, username: String) async {
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty else {
            errorMessage = "Compila tutti i campi."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Le password non coincidono."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "La password deve avere almeno 6 caratteri."
            return
        }
        guard username.count >= 3 else {
            errorMessage = "Il nome utente deve avere almeno 3 caratteri."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Verifica unicità username
        let available = await isUsernameAvailable(username)
        guard available else {
            errorMessage = "Nome utente già in uso. Scegline un altro."
            return
        }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            try await saveUsername(username, userID: result.user.uid)
            currentUser       = result.user
            needsProfileSetup = true   // dovrà scegliere la privacy del profilo
            isAuthenticated   = true
        } catch {
            errorMessage = mapFirebaseError(error)
        }
    }

    // MARK: - Login
    func login(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Compila tutti i campi."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result      = try await Auth.auth().signIn(withEmail: email, password: password)
            currentUser     = result.user
            isAuthenticated = true
        } catch { errorMessage = mapFirebaseError(error) }
    }

    // MARK: - Reset Password
    func resetPassword(email: String) async {
        guard !email.isEmpty else {
            errorMessage = "Inserisci la tua email."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            errorMessage = "Email di recupero inviata. Controlla la posta."
        } catch { errorMessage = mapFirebaseError(error) }
    }

    // MARK: - Google Sign In
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let rootVC      = windowScene.windows.first?.rootViewController
            else { errorMessage = "Impossibile trovare la finestra."; return }

            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Token Google non disponibile."
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken:  idToken,
                accessToken:  result.user.accessToken.tokenString
            )
            let authResult  = try await Auth.auth().signIn(with: credential)
            currentUser     = authResult.user

            // Per Google Sign-In: se è il primo accesso, chiediamo username dopo
            await fetchUsername(userID: authResult.user.uid)
            isAuthenticated = true
        } catch { errorMessage = mapFirebaseError(error) }
    }

    // MARK: - Logout
    func logout() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            currentUser       = nil
            isAuthenticated   = false
            needsProfileSetup = false
            username          = ""
        } catch {
            errorMessage = "Errore durante il logout: \(error.localizedDescription)"
        }
    }

    // MARK: - Elimina account
    // Richiesto dalle Linee Guida App Store (5.1.1 v): un'app che crea account
    // deve permettere all'utente di eliminarlo dall'app, dati inclusi.
    //
    // Ordine: prima si cancellano i dati Firestore (mentre l'utente è ancora
    // autenticato e le Security Rules lo permettono), poi l'account Auth.
    // `deleteAllUserData()` è idempotente, quindi un secondo tentativo dopo un
    // re-login (necessario se Firebase richiede un accesso recente) è sicuro.
    func deleteAccount() async {
        guard let user = Auth.auth().currentUser else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await ItemRepository().deleteAllUserData()

            if !username.isEmpty {
                try await db.collection("usernames").document(username).delete()
            }

            // Rimuove il profilo pubblico così sparisce dalla ricerca.
            try? await db.collection("publicProfiles").document(user.uid).delete()

            try await user.delete()

            GIDSignIn.sharedInstance.signOut()
            currentUser     = nil
            isAuthenticated = false
            username        = ""
        } catch {
            let code = (error as NSError).code
            if code == AuthErrorCode.requiresRecentLogin.rawValue {
                errorMessage = "Per motivi di sicurezza devi aver effettuato l'accesso di recente. Esci, rientra e riprova a eliminare l'account."
            } else {
                errorMessage = mapFirebaseError(error)
            }
        }
    }

    // MARK: - Helpers
    var displayName: String {
        username.isEmpty
            ? (currentUser?.email ?? "Utente")
            : username
    }

    var avatarLetter: String {
        String(displayName.prefix(1)).uppercased()
    }

    private func mapFirebaseError(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:  return "Questa email è già registrata."
        case AuthErrorCode.invalidEmail.rawValue:        return "Formato email non valido."
        case AuthErrorCode.wrongPassword.rawValue,
             AuthErrorCode.invalidCredential.rawValue:   return "Email o password errati."
        case AuthErrorCode.userNotFound.rawValue:        return "Nessun account trovato."
        case AuthErrorCode.weakPassword.rawValue:        return "La password è troppo debole."
        case AuthErrorCode.networkError.rawValue:        return "Errore di rete."
        case AuthErrorCode.tooManyRequests.rawValue:     return "Troppi tentativi. Riprova dopo."
        default:                                         return error.localizedDescription
        }
    }
}
