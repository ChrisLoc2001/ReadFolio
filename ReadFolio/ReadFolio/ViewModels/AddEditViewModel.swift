import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class AddEditViewModel {
    // Form fields
    var title: String = ""
    var contentType: ContentType = .book
    var author: String = ""
    var illustrator: String = ""
    var publisher: String = ""
    var volume: String = ""
    var issueNumber: String = ""
    var chapter: String = ""
    var edition: String = ""
    var status: ReadingStatus = .toRead
    var rating: Int = 0
    var isFavorite: Bool = false
    var startDate: Date? = nil
    var endDate: Date? = nil
    var notes: String = ""
    var genre: String = ""
    var tagInput: String = ""
    var tags: [String] = []
    var coverImageData: Data? = nil
    var isbn: String = ""
    var openLibraryKey: String? = nil

    // State
    var isSearchingMetadata: Bool = false
    var metadataSearchQuery: String = ""
    var metadataResults: [OpenLibraryBook] = []
    var metadataError: String? = nil

    var validationError: String? = nil

    private var repository: ItemRepository?
    private var editingItem: ReadingItem?

    func setup(context: ModelContext, item: ReadingItem? = nil) {
        repository = ItemRepository(context: context)
        if let item {
            editingItem = item
            populateFields(from: item)
        }
    }

    private func populateFields(from item: ReadingItem) {
        title       = item.title
        contentType = item.contentType
        author      = item.author
        illustrator = item.illustrator
        publisher   = item.publisher
        volume      = item.volume.map(String.init) ?? ""
        issueNumber = item.issueNumber.map(String.init) ?? ""
        chapter     = item.chapter.map(String.init) ?? ""
        edition     = item.edition
        status      = item.status
        rating      = item.rating
        isFavorite  = item.isFavorite
        startDate   = item.startDate
        endDate     = item.endDate
        notes       = item.notes
        genre       = item.genre
        tags        = item.tags.map { $0.name }
        coverImageData = item.coverImageData
        isbn        = item.isbn ?? ""
        openLibraryKey = item.openLibraryKey
    }

    var isEditing: Bool { editingItem != nil }

    func validate() -> Bool {
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = "Il titolo è obbligatorio."
            return false
        }
        validationError = nil
        return true
    }

    func save(context: ModelContext) {
        guard validate() else { return }

        if let item = editingItem {
            applyChanges(to: item, context: context)
            item.updatedAt = Date()
            repository?.save()
        } else {
            let item = buildItem(context: context)
            repository?.insert(item)
        }
    }

    private func buildItem(context: ModelContext) -> ReadingItem {
        let item = ReadingItem(
            title: title.trimmingCharacters(in: .whitespaces),
            contentType: contentType,
            author: author,
            illustrator: illustrator,
            publisher: publisher,
            volume: Int(volume),
            issueNumber: Int(issueNumber),
            chapter: Int(chapter),
            edition: edition,
            status: status,
            rating: rating,
            isFavorite: isFavorite,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            genre: genre,
            tags: resolvedTags(context: context),
            coverImageData: coverImageData,
            openLibraryKey: openLibraryKey,
            isbn: isbn.isEmpty ? nil : isbn
        )
        return item
    }

    private func applyChanges(to item: ReadingItem, context: ModelContext) {
        item.title       = title.trimmingCharacters(in: .whitespaces)
        item.contentType = contentType
        item.author      = author
        item.illustrator = illustrator
        item.publisher   = publisher
        item.volume      = Int(volume)
        item.issueNumber = Int(issueNumber)
        item.chapter     = Int(chapter)
        item.edition     = edition
        item.status      = status
        item.rating      = rating
        item.isFavorite  = isFavorite
        item.startDate   = startDate
        item.endDate     = endDate
        item.notes       = notes
        item.genre       = genre
        item.tags        = resolvedTags(context: context)
        if let d = coverImageData { item.coverImageData = d }
        item.openLibraryKey = openLibraryKey
        item.isbn        = isbn.isEmpty ? nil : isbn
    }

    private func resolvedTags(context: ModelContext) -> [Tag] {
        tags.map { name -> Tag in
            let descriptor = FetchDescriptor<Tag>(
                predicate: #Predicate { $0.name == name }
            )
            if let existing = try? context.fetch(descriptor).first {
                return existing
            }
            let tag = Tag(name: name)
            context.insert(tag)
            return tag
        }
    }

    func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        tagInput = ""
    }

    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    // MARK: - Metadata Search

    func searchMetadata() async {
        guard !metadataSearchQuery.isEmpty else { return }
        isSearchingMetadata = true
        metadataError = nil
        defer { isSearchingMetadata = false }

        do {
            metadataResults = try await OpenLibraryService.shared.search(query: metadataSearchQuery)
        } catch {
            metadataError = error.localizedDescription
            metadataResults = []
        }
    }

    func applyMetadata(_ book: OpenLibraryBook) async {
        title          = book.title
        author         = book.authors.joined(separator: ", ")
        publisher      = book.publisher
        isbn           = book.isbn ?? ""
        openLibraryKey = book.id

        if let url = book.coverURL {
            if let data = await OpenLibraryService.shared.fetchCoverData(from: url) {
                coverImageData = ImageService.processImage(data)
            }
        }

        isSearchingMetadata = false
        metadataResults     = []
    }
}
