import Foundation
import SwiftData

@MainActor
final class ItemRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - CRUD

    func insert(_ item: ReadingItem) {
        item.updatedAt = Date()
        context.insert(item)
        save()
    }

    func delete(_ item: ReadingItem) {
        context.delete(item)
        save()
    }

    func duplicate(_ item: ReadingItem) -> ReadingItem {
        let copy = item.duplicate()
        context.insert(copy)
        save()
        return copy
    }

    func save() {
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("SwiftData save error: \(error)")
            #endif
        }
    }

    // MARK: - Fetch

    func fetchAll() throws -> [ReadingItem] {
        let descriptor = FetchDescriptor<ReadingItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchFavorites() throws -> [ReadingItem] {
        let descriptor = FetchDescriptor<ReadingItem>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    // Filtro in memoria: evita il bug di SwiftData con enum.rawValue nei #Predicate
    func fetchByStatus(_ status: ReadingStatus) throws -> [ReadingItem] {
        let all = try fetchAll()
        return all.filter { $0.status == status }
    }

    // MARK: - Statistics

    func countByStatus() throws -> [ReadingStatus: Int] {
        let all = try fetchAll()
        var result: [ReadingStatus: Int] = [:]
        for status in ReadingStatus.allCases {
            result[status] = all.filter { $0.status == status }.count
        }
        return result
    }

    func averageRating() throws -> Double {
        let all = try fetchAll()
        let rated = all.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return 0 }
        return Double(rated.map { $0.rating }.reduce(0, +)) / Double(rated.count)
    }

    /// Elementi completati per mese (ultimi 12 mesi)
    func completedPerMonth() throws -> [MonthStat] {
        let all = try fetchAll()
        let completed = all.filter { $0.status == .completed && $0.endDate != nil }

        let calendar = Calendar.current
        let now = Date()
        var stats: [MonthStat] = []

        for monthOffset in (0..<12).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now)
            else { continue }

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
}

struct MonthStat: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int

    var label: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }
}
