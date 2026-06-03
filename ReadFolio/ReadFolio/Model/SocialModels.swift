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
    var followApprovalRequired: Bool
    var createdAt: Date

    /// Nome mostrato in UI: il display name se presente, altrimenti lo username.
    var name: String {
        displayName.trimmingCharacters(in: .whitespaces).isEmpty ? username : displayName
    }
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
