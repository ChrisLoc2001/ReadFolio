import SwiftUI
import UniformTypeIdentifiers
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showDeleteAccountAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                accountHeader
                Form {
                    infoSection
                    logoutSection
                    dangerZoneSection
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Eliminare l'account?", isPresented: $showDeleteAccountAlert) {
                Button("Elimina account", role: .destructive) {
                    Task { await authVM.deleteAccount() }
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Questa azione è irreversibile: verranno eliminati definitivamente il tuo account e tutta la tua libreria.")
            }
        }
    }

    // MARK: - Account Header (opzione B)

    private var accountHeader: some View {
        VStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 80, height: 80)
                Text(authVM.avatarLetter)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(radius: 4)

            // Nome utente
            Text(authVM.displayName)
                .font(.title2.bold())

            // Email
            if let email = authVM.currentUser?.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.regularMaterial)
    }

    // MARK: - Info

    private var infoSection: some View {
        Section("Info app") {
            LabeledContent("Versione",    value: appVersion)
            LabeledContent("Build",       value: buildNumber)
            LabeledContent("Libri",       value: "Google Books API")
            LabeledContent("Manga",       value: "MangaDex API")
            LabeledContent("Fumetti",     value: "Comic Vine API")
            LabeledContent("Database",    value: "Firebase Firestore")
        }
    }

    // MARK: - Logout

    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                authVM.logout()
            } label: {
                HStack {
                    Spacer()
                    Label("Esci dall'account",
                          systemImage: "rectangle.portrait.and.arrow.right")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Zona pericolosa

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAccountAlert = true
            } label: {
                HStack {
                    Spacer()
                    if authVM.isLoading {
                        ProgressView()
                    } else {
                        Label("Elimina account", systemImage: "person.crop.circle.badge.xmark")
                    }
                    Spacer()
                }
            }
            .disabled(authVM.isLoading)
        } footer: {
            Text("Elimina definitivamente l'account e tutti i dati associati.")
        }
    }

    // MARK: - App info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
