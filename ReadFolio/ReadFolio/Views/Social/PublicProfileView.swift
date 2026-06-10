import SwiftUI

/// Profilo pubblico di un altro utente: header, pulsante Segui/Blocca e — se
/// consentito — la sua libreria in sola lettura.
struct PublicProfileView: View {
    @State private var vm: PublicProfileViewModel
    @State private var showBlockAlert = false

    init(profile: PublicProfile) {
        _vm = State(initialValue: PublicProfileViewModel(profile: profile))
    }

    var body: some View {
        List {
            Section { header }

            Section {
                // Cliccabile in ogni stato: con richiesta "pending" il tap
                // annulla la richiesta di follow.
                Button {
                    Task { await vm.toggleFollow() }
                } label: {
                    HStack {
                        Spacer()
                        Text(vm.followButtonTitle)
                            .fontWeight(.semibold)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showBlockAlert = true
                    } label: {
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

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.accentColor).frame(width: 72, height: 72)
                Text(String(vm.profile.name.prefix(1)).uppercased())
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
            }
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
    }

    private var librarySection: some View {
        Section("Libreria (\(vm.items.count))") {
            if vm.items.isEmpty {
                Text("Nessun elemento nella libreria.")
                    .foregroundStyle(.secondary)
            } else {
                // Sola lettura: nessuna navigazione all'editor (che opererebbe
                // sul repository dell'utente corrente, non su quello visualizzato).
                ForEach(vm.items) { item in
                    LibraryItemRow(item: item)
                }
            }
        }
    }
}
