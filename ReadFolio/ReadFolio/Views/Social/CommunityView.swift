import SwiftUI

/// Tab "Community": ricerca utenti e accesso alle proprie liste social.
struct CommunityView: View {
    @State private var vm = CommunityViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Le tue connessioni") {
                    NavigationLink {
                        FollowListsView(mode: .followers)
                    } label: {
                        Label("Follower", systemImage: "person.2.fill")
                    }
                    NavigationLink {
                        FollowListsView(mode: .following)
                    } label: {
                        Label("Seguiti", systemImage: "person.fill.checkmark")
                    }
                    NavigationLink {
                        FollowListsView(mode: .requests)
                    } label: {
                        HStack {
                            Label("Richieste", systemImage: "person.crop.circle.badge.questionmark")
                            if vm.pendingCount > 0 {
                                Spacer()
                                Text("\(vm.pendingCount)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.red, in: Capsule())
                            }
                        }
                    }
                }

                if !vm.results.isEmpty {
                    Section("Risultati") {
                        ForEach(vm.results) { profile in
                            NavigationLink {
                                PublicProfileView(profile: profile)
                            } label: {
                                ProfileRowLabel(profile: profile)
                            }
                        }
                    }
                } else if !vm.query.trimmingCharacters(in: .whitespaces).isEmpty && !vm.isSearching {
                    Section {
                        Text("Nessun utente trovato.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Community")
            .searchable(text: $vm.query, prompt: "Cerca utenti per nome utente")
            .onSubmit(of: .search) { Task { await vm.search() } }
            .overlay { if vm.isSearching { ProgressView() } }
            .task { await vm.refreshPendingCount() }
            .refreshable { await vm.refreshPendingCount() }
        }
    }
}

/// Riga riutilizzabile che mostra avatar (iniziale), nome e badge privato.
struct ProfileRowLabel: View {
    let profile: PublicProfile

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.accentColor).frame(width: 40, height: 40)
                Text(String(profile.name.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).font(.body.weight(.medium))
                Text("@\(profile.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !profile.isPublic {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
