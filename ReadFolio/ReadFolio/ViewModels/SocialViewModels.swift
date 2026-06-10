import Foundation
import Observation

// MARK: - Ricerca utenti / Community

@Observable
@MainActor
final class CommunityViewModel {
    var query:       String          = ""
    var results:     [PublicProfile] = []
    var isSearching: Bool            = false
    var errorMessage: String?
    var pendingCount: Int            = 0

    private let repo = SocialRepository()

    func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; return }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await repo.searchUsers(prefix: q)
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
    }

    func refreshPendingCount() async {
        pendingCount = (try? await repo.pendingRequests().count) ?? 0
    }
}

// MARK: - Profilo pubblico altrui

@Observable
@MainActor
final class PublicProfileViewModel {
    private(set) var profile: PublicProfile
    var items:        [ReadingItem] = []
    var followStatus: FollowStatus?
    var isLoading:    Bool          = false
    var errorMessage: String?

    private let repo = SocialRepository()

    init(profile: PublicProfile) { self.profile = profile }

    var canViewLibrary: Bool {
        profile.isPublic || followStatus == .accepted
    }

    /// Numero di elementi completati. nil = libreria non accessibile (profilo privato).
    var completedCount: Int? {
        canViewLibrary ? items.filter { $0.status == .completed }.count : nil
    }

    var followButtonTitle: String {
        switch followStatus {
        case .none:     return "Segui"
        case .pending:  return "Annulla Richiesta"
        case .accepted: return "Stai seguendo"
        }
    }

    /// Etichetta mostrata quando la libreria non è accessibile.
    var privateLibraryLabel: String {
        followStatus == .pending ? "Richiesta in attesa di approvazione" : "Profilo privato"
    }

    /// Icona corrispondente allo stato di blocco della libreria.
    var privateLibraryIcon: String {
        followStatus == .pending ? "clock.fill" : "lock.fill"
    }

    /// Testo di supporto sotto la sezione libreria bloccata.
    var privateLibraryFooter: String {
        switch followStatus {
        case .pending:
            return "La tua richiesta è in attesa di approvazione. Potrai vedere la libreria una volta accettata."
        default:
            return "Segui questo utente per vedere la sua libreria. Le richieste vengono approvate dal proprietario."
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        followStatus = try? await repo.followStatus(for: profile.id)
        await loadItemsIfAllowed()
    }

    func toggleFollow() async {
        do {
            if followStatus == nil {
                try await repo.follow(profile)
                followStatus = profile.requiresFollowApproval ? .pending : .accepted
            } else {
                let wasAccepted = (followStatus == .accepted)
                try await repo.unfollow(profile.id, wasAccepted: wasAccepted)
                followStatus = nil
                items = []
            }
            await loadItemsIfAllowed()
            await refreshProfileCounts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func block() async {
        do {
            try await repo.block(profile.id)
            followStatus = nil
            items = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Rilegge i contatori aggiornati del profilo visualizzato (follower/seguiti
    /// cambiano in seguito a un follow/unfollow).
    private func refreshProfileCounts() async {
        if let updated = try? await repo.profile(for: profile.id) {
            profile = updated
        }
    }

    private func loadItemsIfAllowed() async {
        guard canViewLibrary else { items = []; return }
        items = (try? await repo.items(of: profile.id)) ?? []
    }
}

// MARK: - Liste follower / seguiti / richieste

enum FollowListMode: Identifiable {
    case followers, following, requests
    var id: String { title }
    var title: String {
        switch self {
        case .followers: return "Follower"
        case .following: return "Seguiti"
        case .requests:  return "Richieste"
        }
    }
}

@Observable
@MainActor
final class FollowListsViewModel {
    let mode: FollowListMode
    var profiles:     [PublicProfile] = []
    var isLoading:    Bool            = false
    var errorMessage: String?

    /// ID dei richiedenti approvati in questa sessione (mostra "Segui anche tu").
    var approvedIDs:      Set<String>            = []
    /// Cache dei profili approvati (rimossi dalla lista principale ma ancora mostrati).
    var approvedProfiles: [String: PublicProfile] = [:]
    /// ID degli utenti che già seguo (per nascondere "Segui anche tu" se già seguito).
    var followingIDs:     Set<String>            = []

    private let repo = SocialRepository()

    init(mode: FollowListMode) { self.mode = mode }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let edges: [FollowEdge]
        switch mode {
        case .followers: edges = (try? await repo.followers())       ?? []
        case .following: edges = (try? await repo.following())       ?? []
        case .requests:  edges = (try? await repo.pendingRequests()) ?? []
        }
        var resolved: [PublicProfile] = []
        for edge in edges.sorted(by: { $0.createdAt > $1.createdAt }) {
            if let p = try? await repo.profile(for: edge.id) { resolved.append(p) }
        }
        profiles = resolved

        // Carica gli ID degli utenti già seguiti per gestire "Segui anche tu".
        let myFollowing = (try? await repo.following()) ?? []
        followingIDs = Set(myFollowing.map(\.id))
    }

    func approve(_ id: String) async {
        do {
            try await repo.approve(follower: id)
            // Salva il profilo in cache prima di rimuoverlo dalla lista.
            if let profile = profiles.first(where: { $0.id == id }) {
                approvedProfiles[id] = profile
            }
            profiles.removeAll { $0.id == id }
            approvedIDs.insert(id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reject(_ id: String) async {
        // In .requests mode le richieste sono pending → wasAccepted: false
        // In .followers mode il follower è accepted → wasAccepted: true
        let wasAccepted = (mode == .followers)
        try? await repo.removeFollower(id, wasAccepted: wasAccepted)
        profiles.removeAll { $0.id == id }
        approvedIDs.remove(id)
        approvedProfiles.removeValue(forKey: id)
    }

    func unfollow(_ id: String) async {
        try? await repo.unfollow(id, wasAccepted: true)
        profiles.removeAll { $0.id == id }
    }

    /// Segue a propria volta l'utente approvato.
    func followBack(_ profile: PublicProfile) async {
        do {
            try await repo.follow(profile)
            followingIDs.insert(profile.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Utenti bloccati

@Observable
@MainActor
final class BlockedUsersViewModel {
    var profiles:  [PublicProfile] = []
    var isLoading: Bool            = false

    private let repo = SocialRepository()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let ids = (try? await repo.blockedUserIDs()) ?? []
        var resolved: [PublicProfile] = []
        for id in ids {
            if let p = try? await repo.profile(for: id) { resolved.append(p) }
        }
        profiles = resolved
    }

    func unblock(_ id: String) async {
        try? await repo.unblock(id)
        await load()
    }
}

// MARK: - Impostazioni privacy

@Observable
@MainActor
final class PrivacySettingsViewModel {
    var isPublic:  Bool = true
    var isLoading: Bool = false
    var errorMessage: String?

    private let repo = SocialRepository()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        if let p = try? await repo.myPublicProfile() {
            isPublic = p.isPublic
        }
    }

    func save() async {
        do {
            try await repo.updatePrivacy(isPublic: isPublic)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
