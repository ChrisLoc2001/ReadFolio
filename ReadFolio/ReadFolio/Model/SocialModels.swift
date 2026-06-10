import Foundation

/// Profilo "pubblico" di un utente, usato per discovery e visualizzazione da parte
/// di altri. NON contiene dati sensibili (es. email): vive in `publicProfiles/{uid}`
/// ed è leggibile da tutti gli utenti autenticati. I dati privati restano in
/// `users/{uid}/profile/info`, accessibili solo al proprietario.
struct PublicProfile: Identifiable, Codable, Hashable {
    var id: String                      // uid dell'utente
    var username: String
    var displayName: String
    var isPublic: Bool
    var createdAt: Date
    /// Contatori denormalizzati: aggiornati client-side ad ogni follow/unfollow.
    /// Opzionali per compatibilità con documenti creati prima di questo campo.
    var followersCount: Int?
    var followingCount: Int?

    /// Nome mostrato in UI: il display name se presente, altrimenti lo username.
    var name: String {
        displayName.trimmingCharacters(in: .whitespaces).isEmpty ? username : displayName
    }

    /// L'approvazione delle richieste di follow è legata alla privacy:
    /// profilo privato ⇒ il proprietario approva manualmente; pubblico ⇒ follow immediato.
    var requiresFollowApproval: Bool { !isPublic }
}

/// Stato di una relazione di follow.
enum FollowStatus: String, Codable {
    case pending    // richiesta in attesa di approvazione
    case accepted   // follow attivo
}

/// Un arco della rete sociale (follower o seguito). `id` è l'uid dell'altro utente.
struct FollowEdge: Identifiable, Hashable {
    var id: String
    var status: FollowStatus
    var createdAt: Date
}
