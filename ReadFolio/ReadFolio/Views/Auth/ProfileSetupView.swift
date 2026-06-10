import SwiftUI

/// Step mostrato al primo accesso: l'utente sceglie nome visualizzato e privacy
/// del profilo (pubblico/privato; se privato le richieste di follow vanno approvate).
struct ProfileSetupView: View {
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var username:    String = ""
    @State private var displayName: String = ""
    @State private var isPublic:    Bool   = true

    /// Lo username è modificabile solo se non è già stato scelto (es. login Google).
    private var needsUsername: Bool { authVM.username.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if needsUsername {
                        TextField("Nome utente", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        LabeledContent("Nome utente", value: authVM.username)
                    }
                    TextField("Nome visualizzato (opzionale)", text: $displayName)
                } header: {
                    Text("Profilo")
                } footer: {
                    Text("Il nome visualizzato appare agli altri utenti. Se lo lasci vuoto verrà usato il nome utente.")
                }

                Section {
                    Toggle("Profilo pubblico", isOn: $isPublic)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text(privacyExplanation)
                }

                if let error = authVM.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .navigationTitle("Configura il profilo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continua") { Task { await save() } }
                        .disabled(authVM.isLoading)
                }
            }
            .overlay {
                if authVM.isLoading { ProgressView() }
            }
        }
    }

    private var privacyExplanation: String {
        if isPublic {
            return "Chiunque può vedere la tua libreria e chi ti segue viene aggiunto subito."
        } else {
            return "Le richieste di follow dovranno essere approvate da te e solo i follower approvati vedranno la tua libreria."
        }
    }

    private func save() async {
        let ok = await authVM.completeProfileSetup(
            username:    username,
            displayName: displayName,
            isPublic:    isPublic
        )
        // In caso di errore, AuthViewModel.errorMessage viene mostrato nel Form.
        _ = ok
    }
}
