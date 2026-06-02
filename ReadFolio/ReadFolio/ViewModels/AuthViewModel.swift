//
//  AuthViewModel.swift
//  ReadFolio
//
//  Created by Christian Lo Conte on 01/06/2026.
//


import Foundation
import SwiftUI
import FirebaseAuth
import GoogleSignIn
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    
    // MARK: - State
    @Published var isAuthenticated  = false
    @Published var isCheckingAuth   = true
    @Published var isLoading        = false
    @Published var errorMessage:    String?
    @Published var currentUser:     User?

    
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
            }
        }
    }

    // MARK: - Sign Up
    func signUp(email: String, password: String, confirmPassword: String) async {
        guard !email.isEmpty, !password.isEmpty else {
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

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            currentUser     = result.user
            isAuthenticated = true
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
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            currentUser     = result.user
            isAuthenticated = true
        } catch {
            errorMessage = mapFirebaseError(error)
        }
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
        } catch {
            errorMessage = mapFirebaseError(error)
        }
    }

    // MARK: - Google Sign In
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let rootVC = windowScene.windows.first?.rootViewController
            else {
                errorMessage = "Impossibile trovare la finestra dell'app."
                return
            }

            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Token Google non disponibile."
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            let authResult    = try await Auth.auth().signIn(with: credential)
            currentUser       = authResult.user
            isAuthenticated   = true
        } catch {
            errorMessage = mapFirebaseError(error)
        }
    }

    // MARK: - Logout
    func logout() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            currentUser     = nil
            isAuthenticated = false
        } catch {
            errorMessage = "Errore durante il logout: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers
    var displayName: String {
        currentUser?.displayName ?? currentUser?.email ?? "Utente"
    }

    private func mapFirebaseError(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "Questa email è già registrata."
        case AuthErrorCode.invalidEmail.rawValue:
            return "Formato email non valido."
        case AuthErrorCode.wrongPassword.rawValue,
             AuthErrorCode.invalidCredential.rawValue:
            return "Email o password errati."
        case AuthErrorCode.userNotFound.rawValue:
            return "Nessun account trovato con questa email."
        case AuthErrorCode.weakPassword.rawValue:
            return "La password è troppo debole."
        case AuthErrorCode.networkError.rawValue:
            return "Errore di rete. Controlla la connessione."
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Troppi tentativi. Riprova tra qualche minuto."
        default:
            return error.localizedDescription
        }
    }
}
