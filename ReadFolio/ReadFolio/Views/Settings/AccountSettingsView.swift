import SwiftUI
import FirebaseAuth

/// Pagina "Account": mostra e permette di modificare le info del profilo
/// (nome utente, nome visualizzato), i dati di accesso (sola lettura) e la
/// privacy. Le modifiche richiedono una conferma esplicita; il nome utente,
/// se cambiato, viene verificato per unicità.
struct AccountSettingsView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var vm = AccountSettingsViewModel()
    @State private var showConfirm = false

    var body: some View {
        Form {
            Section {
                TextField("Nome utente", text: $vm.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Nome visualizzato", text: $vm.displayName)
            } header: {
                Text("Profilo")
            } footer: {
                Text("Il nome utente è unico e identifica il tuo account. Il nome visualizzato è ciò che vedono gli altri utenti.")
            }

            Section("Accesso") {
                if let email = authVM.currentUser?.email {
                    LabeledContent("Email", value: email)
                }
                LabeledContent("Metodo", value: loginProvider)
            }

            Section {
                Toggle("Profilo pubblico", isOn: $vm.isPublic)
            } header: {
                Text("Privacy")
            } footer: {
                Text(vm.isPublic
                     ? "Chiunque può vedere la tua libreria e chi ti segue viene aggiunto subito."
                     : "Le richieste di follow dovranno essere approvate da te e solo i follower approvati vedranno la tua libreria.")
            }

            if let error = vm.errorMessage ?? authVM.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Salva") { showConfirm = true }
                    .disabled(!vm.hasChanges || vm.isLoading || authVM.isLoading)
            }
        }
        .task { await vm.load() }
        .overlay { if vm.isLoading || authVM.isLoading { ProgressView() } }
        .alert("Confermare le modifiche?", isPresented: $showConfirm) {
            Button("Conferma") { Task { await save() } }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Le modifiche al tuo profilo verranno salvate e saranno visibili agli altri utenti.")
        }
    }

    private func save() async {
        vm.errorMessage = nil
        let ok = await authVM.updateAccount(
            newUsername: vm.username,
            displayName: vm.displayName,
            isPublic:    vm.isPublic
        )
        if ok { vm.markSaved() }
    }

    private var loginProvider: String {
        let id = authVM.currentUser?.providerData.first?.providerID ?? "password"
        switch id {
        case "google.com": return "Google"
        case "apple.com":  return "Apple"
        case "password":   return "Email / Password"
        default:           return id
        }
    }
}
