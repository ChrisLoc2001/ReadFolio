import SwiftUI

/// Tab "Community": ricerca utenti e — in futuro — feed degli aggiornamenti dai follower.
struct CommunityView: View {
    @State private var vm = CommunityViewModel()

    var body: some View {
        NavigationStack {
            List {
                if vm.results.isEmpty && vm.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    feedPlaceholder
                } else if !vm.results.isEmpty {
                    Section("Risultati") {
                        ForEach(vm.results) { profile in
                            NavigationLink {
                                PublicProfileView(profile: profile)
                            } label: {
                                ProfileRowLabel(profile: profile)
                            }
                        }
                    }
                } else if !vm.isSearching {
                    Section {
                        Text("Nessun utente trovato.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Community")
            .searchable(text: $vm.query, prompt: "Cerca utenti per nome utente")
            .onSubmit(of: .search) { Task { await vm.search() } }
            .onChange(of: vm.query) { _, new in
                if new.trimmingCharacters(in: .whitespaces).isEmpty { vm.results = [] }
            }
            .overlay { if vm.isSearching { ProgressView() } }
        }
    }

    private var feedPlaceholder: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "newspaper")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
                Text("Feed in arrivo")
                    .font(.headline)
                Text("Presto potrai vedere gli aggiornamenti dei tuoi follower e delle persone che segui.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .listRowBackground(Color.clear)
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
