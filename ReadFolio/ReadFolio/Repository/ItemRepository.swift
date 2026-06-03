import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class ItemRepository {
    private let db = Firestore.firestore()
    private var userID: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    private var itemsCollection: CollectionReference {
        db.collection("users").document(userID).collection("items")
    }
    private var tagsCollection: CollectionReference {
        db.collection("users").document(userID).collection("tags")
    }

    // MARK: - CRUD Items

    func insert(_ item: ReadingItem) async throws {
        var newItem = item
        newItem.userID    = userID
        newItem.updatedAt = Date()
        try itemsCollection.document(newItem.id).setData(from: newItem)
    }

    func update(_ item: ReadingItem) async throws {
        var updated = item
        updated.updatedAt = Date()
        try itemsCollection.document(item.id).setData(from: updated)
    }

    func delete(_ item: ReadingItem) async throws {
        try await itemsCollection.document(item.id).delete()
        await CoverStorageService.shared.deleteCover(itemID: item.id)
    }

    func duplicate(_ item: ReadingItem) async throws -> ReadingItem {
        let copy = item.duplicate()
        try await insert(copy)
        return copy
    }

    /// Elimina tutti i dati dell'utente corrente (libreria, tag, profilo).
    /// Idempotente: è sicuro richiamarla anche se le collezioni sono già vuote.
    func deleteAllUserData() async throws {
        let items = try await itemsCollection.getDocuments()
        for doc in items.documents {
            await CoverStorageService.shared.deleteCover(itemID: doc.documentID)
            try await doc.reference.delete()
        }

        let tags = try await tagsCollection.getDocuments()
        for doc in tags.documents { try await doc.reference.delete() }

        try await db.collection("users").document(userID)
            .collection("profile").document("info").delete()
    }

    // MARK: - Fetch

    func fetchAll() async throws -> [ReadingItem] {
        let snapshot = try await itemsCollection
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap {
            try? $0.data(as: ReadingItem.self)
        }
    }

    func fetchFavorites() async throws -> [ReadingItem] {
        let snapshot = try await itemsCollection
            .whereField("isFavorite", isEqualTo: true)
            .getDocuments()
        return snapshot.documents.compactMap {
            try? $0.data(as: ReadingItem.self)
        }
    }

    func fetchByStatus(_ status: ReadingStatus) async throws -> [ReadingItem] {
        let snapshot = try await itemsCollection
            .whereField("status", isEqualTo: status.rawValue)
            .getDocuments()
        return snapshot.documents.compactMap {
            try? $0.data(as: ReadingItem.self)
        }
    }

    // MARK: - Tags

    func fetchTags() async throws -> [Tag] {
        let snapshot = try await tagsCollection.getDocuments()
        return snapshot.documents.compactMap {
            try? $0.data(as: Tag.self)
        }
    }

    func resolvedTags(names: [String]) async throws -> [Tag] {
        let existing = try await fetchTags()
        var result: [Tag] = []
        for name in names {
            if let found = existing.first(where: { $0.name == name }) {
                result.append(found)
            } else {
                let tag = Tag(name: name, userID: userID)
                try tagsCollection.document(tag.id).setData(from: tag)
                result.append(tag)
            }
        }
        return result
    }

    // MARK: - Statistics
    //
    // Funzioni pure su un array già caricato: la Dashboard fa UNA sola fetchAll()
    // e calcola tutte le statistiche in memoria, invece di leggere Firestore N volte.

    nonisolated static func countByStatus(in items: [ReadingItem]) -> [ReadingStatus: Int] {
        var result: [ReadingStatus: Int] = [:]
        for status in ReadingStatus.allCases {
            result[status] = items.filter { $0.status == status }.count
        }
        return result
    }

    nonisolated static func averageRating(of items: [ReadingItem]) -> Double {
        let rated = items.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return 0 }
        return Double(rated.map { $0.rating }.reduce(0, +)) / Double(rated.count)
    }

    nonisolated static func completedPerMonth(from items: [ReadingItem]) -> [MonthStat] {
        let completed = items.filter { $0.status == .completed && $0.endDate != nil }
        let calendar  = Calendar.current
        let now       = Date()
        var stats: [MonthStat] = []

        for monthOffset in (0..<12).reversed() {
            guard let monthDate = calendar.date(
                byAdding: .month, value: -monthOffset, to: now
            ) else { continue }

            let comps = calendar.dateComponents([.year, .month], from: monthDate)
            let count = completed.filter { item in
                guard let end = item.endDate else { return false }
                let ic = calendar.dateComponents([.year, .month], from: end)
                return ic.year == comps.year && ic.month == comps.month
            }.count
            stats.append(MonthStat(date: monthDate, count: count))
        }
        return stats
    }

    // MARK: - Export

    func fetchAllForExport() async throws -> [ReadingItem] {
        try await fetchAll()
    }
}

struct MonthStat: Identifiable {
    let id    = UUID()
    let date:  Date
    let count: Int

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    var label: String {
        Self.monthFormatter.string(from: date)
    }
}
