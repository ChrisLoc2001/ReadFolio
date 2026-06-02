import Foundation
import Observation

@Observable
@MainActor
final class ItemDetailViewModel {
    var item:         ReadingItem
    var errorMessage: String?

    private let repository = ItemRepository()

    init(item: ReadingItem) {
        self.item = item
    }

    func toggleFavorite() async {
        item.isFavorite.toggle()
        item.updatedAt = Date()
        do { try await repository.update(item) }
        catch { errorMessage = error.localizedDescription }
    }

    func updateStatus(_ status: ReadingStatus) async {
        item.status = status
        if status == .reading   && item.startDate == nil { item.startDate = Date() }
        if status == .completed && item.endDate   == nil { item.endDate   = Date() }
        item.updatedAt = Date()
        do { try await repository.update(item) }
        catch { errorMessage = error.localizedDescription }
    }

    func delete() async {
        do { try await repository.delete(item) }
        catch { errorMessage = error.localizedDescription }
    }

    var readingDuration: String? {
        guard let start = item.startDate else { return nil }
        let end  = item.endDate ?? Date()
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return days == 0 ? "< 1 giorno" : "\(days) giorni"
    }

    var formattedRating: String {
        item.rating == 0
            ? "Non valutato"
            : String(repeating: "★", count: item.rating)
            + String(repeating: "☆", count: 5 - item.rating)
    }
}
