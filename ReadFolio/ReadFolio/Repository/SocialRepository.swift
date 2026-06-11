import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Errori delle operazioni social.
enum SocialError: LocalizedError {
    /// Operazione di scrittura tentata senza un utente autenticato.
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Devi aver effettuato l'accesso per eseguire questa operazione."
        }
    }
}

/// Accesso Firestore alle funzionalità sociali: profili pubblici, ricerca utenti,
/// follow/unfollow (con eventuale approvazione), richieste, blocco utenti e lettura
/// della libreria altrui.
///
/// Sicurezza: questo repository fa solo da client. L'autorizzazione vera è imposta
/// dalle Security Rules (vedi `firestore.rules`): un utente bloccato o non
/// autorizzato riceverà un errore di permesso anche se chiama questi metodi.
@MainActor
final class SocialRepository {
    private let db = Firestore.firestore()
    private var uid: String { Auth.auth().currentUser?.uid ?? "" }

    /// Restituisce l'uid corrente o lancia se non c'è un utente autenticato.
    /// Da usare all'inizio di ogni metodo di SCRITTURA per evitare di operare
    /// su path Firestore con id vuoto (es. `users//followers/...`).
    @discardableResult
    private func requireUID() throws -> String {
        let id = uid
        guard !id.isEmpty else { throw SocialError.notAuthenticated }
        return id
    }

    private var usersCollection: CollectionReference { db.collection("users") }
    private var publicProfiles:  CollectionReference { db.collection("publicProfiles") }

    // MARK: - Profilo pubblico

    /// Crea o aggiorna il proprio profilo pubblico (discovery + privacy).
    func upsertMyPublicProfile(username: String,
                               displayName: String,
                               isPublic: Bool) async throws {
        try requireUID()
        let profile = PublicProfile(
            id:          uid,
            username:    username.lowercased(),
            displayName: displayName,
            isPublic:    isPublic,
            createdAt:   Date()
        )
        try publicProfiles.document(uid).setData(from: profile, merge: true)
        // Inizializza i contatori SOLO se assenti, così gli incrementi atomici
        // partono da un valore definito senza azzerare conteggi già esistenti.
        let snap = try? await publicProfiles.document(uid).getDocument()
        var seed: [String: Any] = [:]
        if snap?.get("followersCount") == nil { seed["followersCount"] = 0 }
        if snap?.get("followingCount") == nil { seed["followingCount"] = 0 }
        if !seed.isEmpty {
            try? await publicProfiles.document(uid).setData(seed, merge: true)
        }
    }

    /// Aggiorna solo le impostazioni di privacy.
    func updatePrivacy(isPublic: Bool) async throws {
        try requireUID()
        try await publicProfiles.document(uid).setData([
            "isPublic": isPublic
        ], merge: true)
    }

    /// Aggiorna le info del profilo pubblico (username, nome visualizzato, privacy)
    /// SENZA toccare `createdAt` né i contatori — a differenza di `upsert…` che
    /// riscriverebbe la data di creazione.
    func updateProfileInfo(username: String,
                           displayName: String,
                           isPublic: Bool) async throws {
        try requireUID()
        try await publicProfiles.document(uid).setData([
            "username":    username.lowercased(),
            "displayName": displayName,
            "isPublic":    isPublic
        ], merge: true)
    }

    func myPublicProfile() async throws -> PublicProfile? {
        let doc = try await publicProfiles.document(uid).getDocument()
        return try? doc.data(as: PublicProfile.self)
    }

    func profile(for userID: String) async throws -> PublicProfile? {
        let doc = try await publicProfiles.document(userID).getDocument()
        return try? doc.data(as: PublicProfile.self)
    }

    // MARK: - Ricerca utenti

    /// Cerca utenti per prefisso di username. I profili privati compaiono comunque
    /// nei risultati (come su Instagram): è il contenuto della libreria a essere
    /// protetto, non l'esistenza dell'account.
    func searchUsers(prefix: String) async throws -> [PublicProfile] {
        let q = prefix.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        let snap = try await publicProfiles
            .whereField("username", isGreaterThanOrEqualTo: q)
            .whereField("username", isLessThan: q + "\u{f8ff}")
            .limit(to: 25)
            .getDocuments()
        return snap.documents
            .compactMap { try? $0.data(as: PublicProfile.self) }
            .filter { $0.id != uid }
    }

    // MARK: - Follow

    /// Stato della mia relazione di follow verso `userID` (nil se non lo seguo).
    func followStatus(for userID: String) async throws -> FollowStatus? {
        let doc = try await usersCollection.document(userID)
            .collection("followers").document(uid).getDocument()
        guard let raw = doc.data()?["status"] as? String else { return nil }
        return FollowStatus(rawValue: raw)
    }

    /// Segue un utente. Se il profilo del target è privato, la richiesta resta
    /// `pending` finché lui non l'accetta. I contatori vengono aggiornati solo
    /// per i follow immediati (profili pubblici); per quelli privati si aggiornano
    /// al momento dell'approvazione.
    func follow(_ target: PublicProfile) async throws {
        try requireUID()
        let status: FollowStatus = target.requiresFollowApproval ? .pending : .accepted
        let edge: [String: Any] = [
            "status":    status.rawValue,
            "createdAt": Timestamp(date: Date())
        ]
        try await usersCollection.document(target.id)
            .collection("followers").document(uid).setData(edge)
        try await usersCollection.document(uid)
            .collection("following").document(target.id).setData(edge)

        if status == .accepted {
            try? await publicProfiles.document(target.id)
                .updateData(["followersCount": FieldValue.increment(Int64(1))])
            try? await publicProfiles.document(uid)
                .updateData(["followingCount": FieldValue.increment(Int64(1))])
        }
    }

    /// Smette di seguire un utente o annulla una richiesta pending.
    /// `wasAccepted` distingue i due casi per aggiornare i contatori correttamente.
    func unfollow(_ userID: String, wasAccepted: Bool = true) async throws {
        try requireUID()
        try await usersCollection.document(userID)
            .collection("followers").document(uid).delete()
        try await usersCollection.document(uid)
            .collection("following").document(userID).delete()

        if wasAccepted {
            try? await publicProfiles.document(userID)
                .updateData(["followersCount": FieldValue.increment(Int64(-1))])
            try? await publicProfiles.document(uid)
                .updateData(["followingCount": FieldValue.increment(Int64(-1))])
        }
    }

    /// Il proprietario approva una richiesta in attesa.
    func approve(follower userID: String) async throws {
        try requireUID()
        try await usersCollection.document(uid)
            .collection("followers").document(userID)
            .setData(["status": FollowStatus.accepted.rawValue], merge: true)
        // La richiesta era pending: ora conta come follower reale.
        try? await publicProfiles.document(uid)
            .updateData(["followersCount": FieldValue.increment(Int64(1))])
        try? await publicProfiles.document(userID)
            .updateData(["followingCount": FieldValue.increment(Int64(1))])
    }

    /// Rifiuta una richiesta pending o rimuove un follower già accettato.
    /// `wasAccepted` distingue i due casi per aggiornare i contatori correttamente.
    func removeFollower(_ userID: String, wasAccepted: Bool = false) async throws {
        try requireUID()
        try await usersCollection.document(uid)
            .collection("followers").document(userID).delete()
        try? await usersCollection.document(userID)
            .collection("following").document(uid).delete()

        if wasAccepted {
            try? await publicProfiles.document(uid)
                .updateData(["followersCount": FieldValue.increment(Int64(-1))])
            try? await publicProfiles.document(userID)
                .updateData(["followingCount": FieldValue.increment(Int64(-1))])
        }
    }

    /// Follower accettati di un altro utente (richiede profilo pubblico o essere follower).
    func followers(of userID: String) async throws -> [FollowEdge] {
        let snap = try await usersCollection.document(userID)
            .collection("followers")
            .whereField("status", isEqualTo: FollowStatus.accepted.rawValue)
            .getDocuments()
        return snap.documents.compactMap(Self.decodeEdge)
    }

    /// Seguiti accettati di un altro utente.
    func following(of userID: String) async throws -> [FollowEdge] {
        let snap = try await usersCollection.document(userID)
            .collection("following")
            .whereField("status", isEqualTo: FollowStatus.accepted.rawValue)
            .getDocuments()
        return snap.documents.compactMap(Self.decodeEdge)
    }

    func followers() async throws -> [FollowEdge] {
        let snap = try await usersCollection.document(uid)
            .collection("followers")
            .whereField("status", isEqualTo: FollowStatus.accepted.rawValue)
            .getDocuments()
        return snap.documents.compactMap(Self.decodeEdge)
    }

    func following() async throws -> [FollowEdge] {
        let snap = try await usersCollection.document(uid)
            .collection("following")
            .whereField("status", isEqualTo: FollowStatus.accepted.rawValue)
            .getDocuments()
        return snap.documents.compactMap(Self.decodeEdge)
    }

    /// ID di tutti gli utenti verso cui ho un edge di following, a prescindere
    /// dallo stato. Usato per rilevare follow già inviati (anche pending) e
    /// non mostrare erroneamente "Segui anche tu" nella lista richieste.
    func allFollowingIDs() async throws -> [String] {
        let snap = try await usersCollection.document(uid)
            .collection("following").getDocuments()
        return snap.documents.map(\.documentID)
    }

    func pendingRequests() async throws -> [FollowEdge] {
        let snap = try await usersCollection.document(uid)
            .collection("followers")
            .whereField("status", isEqualTo: FollowStatus.pending.rawValue)
            .getDocuments()
        return snap.documents.compactMap(Self.decodeEdge)
    }

    /// Allinea i miei edge `following` rimasti `pending` allo stato reale.
    ///
    /// Quando seguo un profilo PRIVATO, l'approvazione del proprietario scrive
    /// `accepted` nel SUO albero (`followers/{me}`) ma non può toccare il mio
    /// `following/{target}` (le regole vietano la scrittura nel sottoalbero altrui):
    /// resta `pending`. Di conseguenza la lista "Seguiti" (filtrata su `accepted`)
    /// non mostrerebbe quei profili. Qui leggo lo stato autoritativo nell'albero
    /// del target e promuovo a `accepted`, oppure elimino l'edge orfano se la
    /// richiesta è stata rifiutata/rimossa.
    func reconcileFollowing() async {
        guard !uid.isEmpty else { return }
        guard let snap = try? await usersCollection.document(uid)
            .collection("following")
            .whereField("status", isEqualTo: FollowStatus.pending.rawValue)
            .getDocuments() else { return }

        for doc in snap.documents {
            // Stato autoritativo: il mio record follower nell'albero del target.
            // getDocument non lancia se il documento è assente (ritorna nil);
            // lancia solo su errori reali (rete/permessi) → in quel caso non tocco nulla.
            do {
                let real = try await followStatus(for: doc.documentID)
                if real == .accepted {
                    try? await doc.reference.setData(
                        ["status": FollowStatus.accepted.rawValue], merge: true)
                } else if real == nil {
                    // Richiesta rifiutata o rimossa: edge orfano, lo elimino.
                    // Era pending ⇒ il followingCount non era stato incrementato.
                    try? await doc.reference.delete()
                }
                // real == .pending ⇒ ancora in attesa, lascio invariato.
            } catch {
                continue
            }
        }
    }

    // MARK: - Blocco utenti

    /// Blocca un utente: rimuove ogni relazione reciproca di follow e impedisce
    /// (via Security Rules) che l'utente bloccato veda la libreria o invii follow.
    func block(_ userID: String) async throws {
        try requireUID()
        try await usersCollection.document(uid)
            .collection("blocked").document(userID)
            .setData(["createdAt": Timestamp(date: Date())])

        // Leggo lo stato reale prima di eliminare, per decrementare i contatori
        // solo se il follow era effettivamente accettato (non pending).
        let myFollowDoc = try? await usersCollection.document(uid)
            .collection("following").document(userID).getDocument()
        let iFollowedAccepted = myFollowDoc?.data()?["status"] as? String == FollowStatus.accepted.rawValue

        let theirFollowDoc = try? await usersCollection.document(uid)
            .collection("followers").document(userID).getDocument()
        let theyFollowedAccepted = theirFollowDoc?.data()?["status"] as? String == FollowStatus.accepted.rawValue

        try? await unfollow(userID, wasAccepted: iFollowedAccepted)
        try? await removeFollower(userID, wasAccepted: theyFollowedAccepted)
        // Rimuove i mirror nell'albero dell'utente bloccato (già gestiti da unfollow/removeFollower).
    }

    func unblock(_ userID: String) async throws {
        try requireUID()
        try await usersCollection.document(uid)
            .collection("blocked").document(userID).delete()
    }

    func blockedUserIDs() async throws -> [String] {
        let snap = try await usersCollection.document(uid)
            .collection("blocked").getDocuments()
        return snap.documents.map(\.documentID)
    }

    // MARK: - Eliminazione account

    /// Cancella tutte le tracce social dell'utente corrente. Chiamata durante
    /// l'eliminazione dell'account, PRIMA di eliminare l'utente Auth (le Security
    /// Rules richiedono che sia ancora autenticato).
    ///
    /// Pulisce:
    ///  - le relazioni negli alberi ALTRUI: il mio record `followers` da chi seguivo
    ///    e il mio record `following` da chi mi seguiva (consentito dalle rules);
    ///  - le mie sottocollezioni `followers`, `following`, `blocked`;
    ///  - il mio documento `publicProfiles` (sparisce dalla ricerca).
    ///
    /// Ogni passo è best effort e idempotente: un secondo tentativo dopo un
    /// re-login è sicuro.
    func deleteAllSocialData() async {
        let myUID = uid
        guard !myUID.isEmpty else { return }

        // 1. Smetto di seguire tutti (rimuove i miei record dagli alberi altrui).
        if let followingSnap = try? await usersCollection.document(myUID)
            .collection("following").getDocuments() {
            for doc in followingSnap.documents {
                try? await usersCollection.document(doc.documentID)
                    .collection("followers").document(myUID).delete()
                try? await doc.reference.delete()
            }
        }

        // 2. Rimuovo i miei follower (e il mirror nella loro lista "following").
        if let followersSnap = try? await usersCollection.document(myUID)
            .collection("followers").getDocuments() {
            for doc in followersSnap.documents {
                try? await usersCollection.document(doc.documentID)
                    .collection("following").document(myUID).delete()
                try? await doc.reference.delete()
            }
        }

        // 3. Svuoto la lista dei bloccati.
        if let blockedSnap = try? await usersCollection.document(myUID)
            .collection("blocked").getDocuments() {
            for doc in blockedSnap.documents {
                try? await doc.reference.delete()
            }
        }

        // 4. Elimino il profilo pubblico.
        try? await publicProfiles.document(myUID).delete()
    }

    // MARK: - Libreria altrui

    /// Legge la libreria di un altro utente. Le Security Rules consentono la lettura
    /// solo se il profilo è pubblico o se siamo follower accettati (e non bloccati).
    func items(of userID: String) async throws -> [ReadingItem] {
        let snap = try await usersCollection.document(userID)
            .collection("items")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snap.documents.compactMap { try? $0.data(as: ReadingItem.self) }
    }

    // MARK: - Helpers

    private static func decodeEdge(_ doc: QueryDocumentSnapshot) -> FollowEdge? {
        let data = doc.data()
        guard let raw = data["status"] as? String,
              let status = FollowStatus(rawValue: raw) else { return nil }
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return FollowEdge(id: doc.documentID, status: status, createdAt: createdAt)
    }
}
