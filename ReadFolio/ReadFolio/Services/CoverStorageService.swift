import Foundation
import FirebaseStorage
import FirebaseAuth

enum CoverStorageError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Devi aver effettuato l'accesso per salvare la copertina."
        }
    }
}

actor CoverStorageService {
    static let shared = CoverStorageService()

    private let storage = Storage.storage()

    private func coverRef(itemID: String) throws -> StorageReference {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw CoverStorageError.notAuthenticated
        }
        return storage.reference().child("users/\(uid)/covers/\(itemID).jpg")
    }

    /// Carica i dati JPEG già compressi e restituisce l'URL di download.
    func uploadCover(_ data: Data, itemID: String) async throws -> String {
        let ref = try coverRef(itemID: itemID)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    /// Elimina la copertina associata a un elemento. Silenzioso se non esiste.
    func deleteCover(itemID: String) async {
        guard let ref = try? coverRef(itemID: itemID) else { return }
        try? await ref.delete()
    }
}
