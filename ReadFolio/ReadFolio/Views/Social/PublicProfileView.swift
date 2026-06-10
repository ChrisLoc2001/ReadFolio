import SwiftUI

/// Profilo pubblico di un altro utente: header, pulsante Segui/Blocca e — se
/// consentito — la sua libreria in sola lettura.
struct PublicProfileView: View {
    @State private var vm: PublicProfileViewModel
    @State private var showBlockAlert = false
    @State private var statDest: StatDest? = nil

    init(profile: PublicProfile) {
        _vm = State(initialValue: PublicProfileViewModel(profile: profile))
    }

    var body: some View {
        List {
            Section { header }

            Section {
                Button {
                    Task { await vm.toggleFollow() }
                } label: {
                    HStack {
                        Spacer()
                        Text(vm.followButtonTitle).fontWeight(.semibold)
                        Spacer()
                    }
                }
            }

            if vm.canViewLibrary {
                librarySection
            } else {
                Section {
                    Label(vm.privateLibraryLabel, systemImage: vm.privateLibraryIcon)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text(vm.privateLibraryFooter)
                }
            }
        }
        .navigationTitle(vm.profile.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $statDest) { dest in
            switch dest {
            case .letti:
                ItemsPreviewView(
                    items: vm.items.filter { $0.status == .completed },
                    title: "Libri letti"
                )
            case .follower:
                PublicFollowListView(userID: vm.profile.id, mode: .followers)
            case .seguiti:
                PublicFollowListView(userID: vm.profile.id, mode: .following)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) { showBlockAlert = true } label: {
                        Label("Blocca utente", systemImage: "hand.raised.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Bloccare @\(vm.profile.username)?", isPresented: $showBlockAlert) {
            Button("Blocca", role: .destructive) { Task { await vm.block() } }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("L'utente non potrà più vedere la tua libreria e verranno rimosse le relazioni di follow reciproche.")
        }
        .overlay { if vm.isLoading { ProgressView() } }
        .task { await vm.load() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.accentColor).frame(width: 72, height: 72)
                Text(String(vm.profile.name.prefix(1)).uppercased())
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 4) {
                Text(vm.profile.name).font(.title3.bold())
                Text("@\(vm.profile.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !vm.profile.isPublic {
                    Label("Profilo privato", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 0) {
                statCell(
                    value: vm.completedCount.map { "\($0)" } ?? "—",
                    label: "Letti",
                    action: vm.canViewLibrary ? { statDest = .letti } : nil
                )
                Divider().frame(height: 32)
                statCell(
                    value: "\(max(0, vm.profile.followersCount ?? 0))",
                    label: "Follower",
                    action: { statDest = .follower }
                )
                Divider().frame(height: 32)
                statCell(
                    value: "\(max(0, vm.profile.followingCount ?? 0))",
                    label: "Seguiti",
                    action: { statDest = .seguiti }
                )
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
    }

    private func statCell(value: String, label: String, action: (() -> Void)? = nil) -> some View {
        Group {
            if let action {
                Button(action: action) { statCellBody(value: value, label: label) }
                    .buttonStyle(.plain)
            } else {
                statCellBody(value: value, label: label)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statCellBody(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Library

    private var librarySection: some View {
        Section("Libreria (\(vm.items.count))") {
            if vm.items.isEmpty {
                Text("Nessun elemento nella libreria.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.items) { item in
                    LibraryItemRow(item: item)
                }
            }
        }
    }
}

// MARK: - Navigation destinations

private enum StatDest: Hashable {
    case letti, follower, seguiti
}
