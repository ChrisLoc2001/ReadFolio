import SwiftUI

/// Lista follower o seguiti di un altro utente, in sola lettura.
/// Accessibile solo per profili pubblici o se si è già follower accettati.
struct PublicFollowListView: View {
    @State private var vm: PublicFollowListViewModel

    init(userID: String, mode: FollowListMode) {
        _vm = State(initialValue: PublicFollowListViewModel(userID: userID, mode: mode))
    }

    var body: some View {
        List {
            if vm.isLoading {
                // Scheletro durante il caricamento
            } else if let error = vm.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            } else if vm.profiles.isEmpty {
                ContentUnavailableView(
                    "Nessun utente",
                    systemImage: "person.2",
                    description: Text(vm.mode == .followers
                        ? "Nessuno segue ancora questo profilo."
                        : "Questo profilo non segue ancora nessuno.")
                )
            } else {
                ForEach(vm.profiles) { profile in
                    NavigationLink {
                        PublicProfileView(profile: profile)
                    } label: {
                        ProfileRowLabel(profile: profile)
                    }
                }
            }
        }
        .navigationTitle(vm.mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if vm.isLoading { ProgressView() } }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}
