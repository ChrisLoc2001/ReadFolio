import SwiftUI

/// Impostazioni di privacy del profilo social.
struct PrivacySettingsView: View {
    @State private var vm = PrivacySettingsViewModel()

    var body: some View {
        Form {
            Section {
                Toggle("Profilo pubblico", isOn: $vm.isPublic)
                Toggle("Approva i follower manualmente", isOn: $vm.followApprovalRequired)
            } footer: {
                Text(vm.isPublic
                     ? "Chiunque può vedere la tua libreria."
                     : "Solo i follower che approvi possono vedere la tua libreria.")
            }

            if let error = vm.errorMessage {
                Text(error).foregroundStyle(.red).font(.footnote)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        // Salva ad ogni modifica dei toggle.
        .onChange(of: vm.isPublic)               { Task { await vm.save() } }
        .onChange(of: vm.followApprovalRequired) { Task { await vm.save() } }
        .overlay { if vm.isLoading { ProgressView() } }
    }
}

/// Elenco degli utenti bloccati con possibilità di sbloccarli.
struct BlockedUsersView: View {
    @State private var vm = BlockedUsersViewModel()

    var body: some View {
        List {
            if vm.profiles.isEmpty && !vm.isLoading {
                Text("Nessun utente bloccato.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.profiles) { profile in
                    HStack {
                        ProfileRowLabel(profile: profile)
                        Spacer()
                        Button("Sblocca") { Task { await vm.unblock(profile.id) } }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .navigationTitle("Utenti bloccati")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if vm.isLoading { ProgressView() } }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}
