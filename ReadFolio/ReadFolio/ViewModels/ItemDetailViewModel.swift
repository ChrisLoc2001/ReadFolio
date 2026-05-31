import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class ItemDetailViewModel {
    var item: ReadingItem
    private var repository: ItemRepository?

    init(item: ReadingItem) {
        self.item = item
    }

    func setup(context: ModelContext) {
        repository = ItemRepository(context: context)
    }

    func toggleFavorite() {
        item.isFavorite.toggle()
        item.updatedAt = Date()
        repository?.save()
    }

    func updateStatus(_ status: ReadingStatus) {
        item.status = status
        if status == .reading && item.startDate == nil {
            item.startDate = Date()
        }
        if status == .completed && item.endDate == nil {
            item.endDate = Date()
        }
        item.updatedAt = Date()
        repository?.save()
    }

    func delete() {
        repository?.delete(item)
    }

    var readingDuration: String? {
        guard let start = item.startDate else { return nil }
        let end = item.endDate ?? Date()
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return days == 0 ? "< 1 giorno" : "\(days) giorni"
    }

    var formattedRating: String {
        item.rating == 0 ? "Non valutato" : String(repeating: "★", count: item.rating)
                        + String(repeating: "☆", count: 5 - item.rating)
    }
}
