import Foundation
import SwiftData
import Observation

enum SortOption: String, CaseIterable, Identifiable {
    case dateAdded   = "Data aggiunta"
    case title       = "Titolo"
    case author      = "Autore"
    case rating      = "Valutazione"
    case updatedAt   = "Aggiornato"
    var id: String { rawValue }
}

@Observable
@MainActor
final class LibraryViewModel {
    var allItems: [ReadingItem] = []
    var searchText: String = ""
    var selectedType: ContentType? = nil
    var selectedStatus: ReadingStatus? = nil
    var sortOption: SortOption = .dateAdded
    var sortAscending: Bool = false
    var showFavoritesOnly: Bool = false
    var isLoading = false
    var errorMessage: String?

    private var repository: ItemRepository?

    func setup(context: ModelContext) {
        repository = ItemRepository(context: context)
    }

    func load() async {
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            allItems = try repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var filteredItems: [ReadingItem] {
        var items = allItems

        if showFavoritesOnly {
            items = items.filter { $0.isFavorite }
        }
        if let type = selectedType {
            items = items.filter { $0.contentType == type }
        }
        if let status = selectedStatus {
            items = items.filter { $0.status == status }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            items = items.filter {
                $0.title.lowercased().contains(q) ||
                $0.author.lowercased().contains(q) ||
                $0.genre.lowercased().contains(q) ||
                $0.tags.contains { $0.name.lowercased().contains(q) }
            }
        }

        items.sort { lhs, rhs in
            let result: Bool
            switch sortOption {
            case .dateAdded: result = lhs.createdAt < rhs.createdAt
            case .title:     result = lhs.title.localizedCompare(rhs.title) == .orderedAscending
            case .author:    result = lhs.author.localizedCompare(rhs.author) == .orderedAscending
            case .rating:    result = lhs.rating < rhs.rating
            case .updatedAt: result = lhs.updatedAt < rhs.updatedAt
            }
            return sortAscending ? result : !result
        }

        return items
    }

    func delete(_ item: ReadingItem) {
        repository?.delete(item)
        allItems.removeAll { $0.id == item.id }
    }

    func duplicate(_ item: ReadingItem) {
        guard let repo = repository else { return }
        let copy = repo.duplicate(item)
        allItems.insert(copy, at: 0)
    }

    func toggleFavorite(_ item: ReadingItem) {
        item.isFavorite.toggle()
        item.updatedAt = Date()
        repository?.save()
    }
}
