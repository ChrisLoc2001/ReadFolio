import SwiftUI

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
