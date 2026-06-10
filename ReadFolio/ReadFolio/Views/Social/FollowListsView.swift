import SwiftUI

/// Lista di follower / seguiti / richieste, con azioni contestuali.
struct FollowListsView: View {
    @State private var vm: FollowListsViewModel

    init(mode: FollowListMode) {
        _vm = State(initialValue: FollowListsViewModel(mode: mode))
    }

    var body: some View {
        List {
            if vm.profiles.isEmpty && !vm.isLoading && vm.approvedIDs.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
            } else {
                // Sezione richieste approvate con pulsante "Segui anche tu".
                if vm.mode == .requests && !vm.approvedIDs.isEmpty {
                    approvedSection
                }

                ForEach(vm.profiles) { profile in
                    if vm.mode == .requests {
                        requestRow(for: profile)
                    } else {
                        NavigationLink {
                            PublicProfileView(profile: profile)
                        } label: {
                            ProfileRowLabel(profile: profile)
                        }
                        .swipeActions(edge: .trailing) { swipeActions(for: profile) }
                    }
                }
            }
        }
        .navigationTitle(vm.mode.title)
        .overlay { if vm.isLoading { ProgressView() } }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    // MARK: - Riga richiesta di follow (con pulsanti inline)

    private func requestRow(for profile: PublicProfile) -> some View {
        HStack(spacing: 12) {
            NavigationLink {
                PublicProfileView(profile: profile)
            } label: {
                ProfileRowLabel(profile: profile)
            }

            Spacer()

            // ✅ Approva
            Button {
                Task { await vm.approve(profile.id) }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)

            // ✖ Rifiuta
            Button {
                Task { await vm.reject(profile.id) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Sezione richieste approvate

    @ViewBuilder
    private var approvedSection: some View {
        Section("Approvate di recente") {
            ForEach(Array(vm.approvedIDs), id: \.self) { approvedID in
                if let profile = profileForID(approvedID) {
                    approvedRow(for: profile)
                }
            }
        }
    }

    private func approvedRow(for profile: PublicProfile) -> some View {
        HStack(spacing: 12) {
            NavigationLink {
                PublicProfileView(profile: profile)
            } label: {
                ProfileRowLabel(profile: profile)
            }

            Spacer()

            if vm.followingIDs.contains(profile.id) {
                // Già seguito dopo l'approvazione.
                Label("Seguito", systemImage: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    Task { await vm.followBack(profile) }
                } label: {
                    Text("Segui anche tu")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Swipe actions (followers / following)

    @ViewBuilder
    private func swipeActions(for profile: PublicProfile) -> some View {
        switch vm.mode {
        case .followers:
            Button(role: .destructive) { Task { await vm.reject(profile.id) } } label: {
                Label("Rimuovi", systemImage: "person.fill.xmark")
            }
        case .following:
            Button(role: .destructive) { Task { await vm.unfollow(profile.id) } } label: {
                Label("Smetti", systemImage: "person.fill.xmark")
            }
        case .requests:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private var emptyMessage: String {
        switch vm.mode {
        case .followers: return "Non hai ancora follower."
        case .following: return "Non segui ancora nessuno."
        case .requests:  return "Nessuna richiesta in attesa."
        }
    }

    /// Cerca il profilo tra quelli già caricati, oppure tra gli approvati
    /// che sono stati rimossi dalla lista principale.
    private func profileForID(_ id: String) -> PublicProfile? {
        vm.profiles.first { $0.id == id }
        ?? vm.approvedProfiles[id]
    }
}
