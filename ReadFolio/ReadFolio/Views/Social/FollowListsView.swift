import SwiftUI

/// Lista di follower / seguiti / richieste, con azioni contestuali.
struct FollowListsView: View {
    @State private var vm: FollowListsViewModel

    init(mode: FollowListMode) {
        _vm = State(initialValue: FollowListsViewModel(mode: mode))
    }

    var body: some View {
        List {
            if vm.profiles.isEmpty && !vm.isLoading {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.profiles) { profile in
                    NavigationLink {
                        PublicProfileView(profile: profile)
                    } label: {
                        ProfileRowLabel(profile: profile)
                    }
                    .swipeActions(edge: .trailing) { actions(for: profile) }
                }
            }
        }
        .navigationTitle(vm.mode.title)
        .overlay { if vm.isLoading { ProgressView() } }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    @ViewBuilder
    private func actions(for profile: PublicProfile) -> some View {
        switch vm.mode {
        case .requests:
            Button { Task { await vm.approve(profile.id) } } label: {
                Label("Approva", systemImage: "checkmark")
            }
            .tint(.green)
            Button(role: .destructive) { Task { await vm.reject(profile.id) } } label: {
                Label("Rifiuta", systemImage: "xmark")
            }
        case .followers:
            Button(role: .destructive) { Task { await vm.reject(profile.id) } } label: {
                Label("Rimuovi", systemImage: "person.fill.xmark")
            }
        case .following:
            Button(role: .destructive) { Task { await vm.unfollow(profile.id) } } label: {
                Label("Smetti", systemImage: "person.fill.xmark")
            }
        }
    }

    private var emptyMessage: String {
        switch vm.mode {
        case .followers: return "Non hai ancora follower."
        case .following: return "Non segui ancora nessuno."
        case .requests:  return "Nessuna richiesta in attesa."
        }
    }
}
