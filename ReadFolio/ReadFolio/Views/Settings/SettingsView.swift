import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showDeleteAccountAlert = false

    // Stats del profilo corrente
    @State private var completedCount:  Int? = nil
    @State private var followersCount:  Int? = nil
    @State private var followingCount:  Int? = nil
    @State private var pendingCount:    Int  = 0

    private let socialRepo = SocialRepository()
    private let itemRepo   = ItemRepository()

    var body: some View {
        NavigationStack {
            List {
                // Header stile Instagram (fuori dal Form per non avere padding di cella)
                Section {
                    profileHeader
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init())
                }

                Section("Social") {
                    NavigationLink {
                        FollowListsView(mode: .requests)
                    } label: {
                        HStack {
                            Label("Richieste", systemImage: "person.crop.circle.badge.questionmark")
                            if pendingCount > 0 {
                                Spacer()
                                Text("\(pendingCount)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.red, in: Capsule())
                            }
                        }
                    }
                    NavigationLink {
                        BlockedUsersView()
                    } label: {
                        Label("Utenti bloccati", systemImage: "hand.raised")
                    }
                }

                Section("Account") {
                    NavigationLink {
                        AccountSettingsView()
                    } label: {
                        Label("Gestisci account", systemImage: "person.text.rectangle")
                    }
                }

                Section {
                    NavigationLink {
                        AppInfoView()
                    } label: {
                        Label("Info", systemImage: "info.circle")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        authVM.logout()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Esci dall'account",
                                  systemImage: "rectangle.portrait.and.arrow.right")
                            Spacer()
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteAccountAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            if authVM.isLoading {
                                ProgressView()
                            } else {
                                Label("Elimina account",
                                      systemImage: "person.crop.circle.badge.xmark")
                            }
                            Spacer()
                        }
                    }
                    .disabled(authVM.isLoading)
                } footer: {
                    Text("Elimina definitivamente l'account e tutti i dati associati.")
                }
            }
            .navigationTitle("Profilo")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { Task { await loadStats() } }
            .refreshable { await loadStats() }
            .alert("Eliminare l'account?", isPresented: $showDeleteAccountAlert) {
                Button("Elimina account", role: .destructive) {
                    Task { await authVM.deleteAccount() }
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Questa azione è irreversibile: verranno eliminati definitivamente il tuo account e tutta la tua libreria.")
            }
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 80, height: 80)
                Text(authVM.avatarLetter)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Nome e username
            VStack(spacing: 4) {
                Text(authVM.displayName)
                    .font(.title2.bold())
                if !authVM.username.isEmpty {
                    Text("@\(authVM.username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Statistiche
            HStack(spacing: 0) {
                statCell(
                    value: completedCount.map { "\($0)" } ?? "—",
                    label: "Letti"
                )
                Divider().frame(height: 32)
                statCell(
                    value: "\(max(0, followersCount ?? 0))",
                    label: "Follower"
                )
                Divider().frame(height: 32)
                statCell(
                    value: "\(max(0, followingCount ?? 0))",
                    label: "Seguiti"
                )
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Caricamento stats

    private func loadStats() async {
        async let profile  = socialRepo.myPublicProfile()
        async let items    = try? itemRepo.fetchAll()
        async let pending  = socialRepo.pendingRequests()

        let p = try? await profile
        followersCount = p?.followersCount
        followingCount = p?.followingCount
        completedCount = (await items)?.filter { $0.status == .completed }.count
        pendingCount   = (try? await pending)?.count ?? 0
    }
}
