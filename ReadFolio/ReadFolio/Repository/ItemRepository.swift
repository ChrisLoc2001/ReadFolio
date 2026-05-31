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
            print("SwiftData save error: \(error)")
        }
    }

    // MARK: - Fetch helpers

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

    func fetchByStatus(_ status: ReadingStatus) throws -> [ReadingItem] {
        let raw = status.rawValue
        let descriptor = FetchDescriptor<ReadingItem>(
            predicate: #Predicate { $0.status.rawValue == raw },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Statistics

    func countByStatus() throws -> [ReadingStatus: Int] {
        var result: [ReadingStatus: Int] = [:]
        for status in ReadingStatus.allCases {
            let raw = status.rawValue
            let descriptor = FetchDescriptor<ReadingItem>(
                predicate: #Predicate { $0.status.rawValue == raw }
            )
            result[status] = try context.fetchCount(descriptor)
        }
        return result
    }

    func averageRating() throws -> Double {
        let all = try fetchAll()
        let rated = all.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return 0 }
        return Double(rated.map { $0.rating }.reduce(0, +)) / Double(rated.count)
    }

    /// Libri completati per mese (ultimi 12 mesi)
    func completedPerMonth() throws -> [MonthStat] {
        let raw = ReadingStatus.completed.rawValue
        let descriptor = FetchDescriptor<ReadingItem>(
            predicate: #Predicate { $0.status.rawValue == raw && $0.endDate != nil }
        )
        let items = try context.fetch(descriptor)
        let calendar = Calendar.current
        let now = Date()

        var stats: [MonthStat] = []
        for monthOffset in (0..<12).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now) else { continue }
            let comps = calendar.dateComponents([.year, .month], from: monthDate)
            let count = items.filter { item in
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
