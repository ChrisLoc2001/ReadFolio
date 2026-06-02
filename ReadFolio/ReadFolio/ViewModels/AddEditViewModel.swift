import Foundation
import Observation

@Observable
@MainActor
final class AddEditViewModel {
    var title:          String        = ""
    var contentType:    ContentType   = .book
    var author:         String        = ""
    var illustrator:    String        = ""
    var publisher:      String        = ""
    var volume:         String        = ""
    var issueNumber:    String        = ""
    var chapter:        String        = ""
    var edition:        String        = ""
    var status:         ReadingStatus = .toRead
    var rating:         Int           = 0
    var isFavorite:     Bool          = false
    var startDate:      Date?         = nil
    var endDate:        Date?         = nil
    var notes:          String        = ""
    var genre:          String        = ""
    var tagInput:       String        = ""
    var tags:           [String]      = []
    var coverImageData: Data?         = nil
    var isbn:           String        = ""
    var openLibraryKey: String?       = nil

    var isSearchingMetadata: Bool               = false
    var metadataSearchQuery: String             = ""
    var metadataResults:     [MediaSearchResult] = []
    var metadataError:       String?            = nil
    var selectedSource:      SearchSource       = .auto

    var validationError: String? = nil
    var isSaving        = false

    private let repository  = ItemRepository()
    private var editingItem: ReadingItem?

    // MARK: - Setup

    func setup(item: ReadingItem? = nil) {
        if let item {
            editingItem = item
            populateFields(from: item)
        }
    }

    private func populateFields(from item: ReadingItem) {
        title          = item.title
        contentType    = item.contentType
        author         = item.author
        illustrator    = item.illustrator
        publisher      = item.publisher
        volume         = item.volume.map(String.init) ?? ""
        issueNumber    = item.issueNumber.map(String.init) ?? ""
        chapter        = item.chapter.map(String.init) ?? ""
        edition        = item.edition
        status         = item.status
        rating         = item.rating
        isFavorite     = item.isFavorite
        startDate      = item.startDate
        endDate        = item.endDate
        notes          = item.notes
        genre          = item.genre
        tags           = item.tags
        coverImageData = item.coverImageData
        isbn           = item.isbn ?? ""
        openLibraryKey = item.openLibraryKey
    }

    var isEditing: Bool { editingItem != nil }

    // MARK: - Validation & Save

    func validate() -> Bool {
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = "Il titolo è obbligatorio."
            return false
        }
        validationError = nil
        return true
    }

    func save() async {
        guard validate() else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            if var item = editingItem {
                applyChanges(to: &item)
                try await repository.update(item)
            } else {
                let item = buildItem()
                try await repository.insert(item)
            }
        } catch {
            validationError = error.localizedDescription
        }
    }

    private func buildItem() -> ReadingItem {
        ReadingItem(
            title:          title.trimmingCharacters(in: .whitespaces),
            contentType:    contentType,
            author:         author,
            illustrator:    illustrator,
            publisher:      publisher,
            volume:         Int(volume),
            issueNumber:    Int(issueNumber),
            chapter:        Int(chapter),
            edition:        edition,
            status:         status,
            rating:         rating,
            isFavorite:     isFavorite,
            startDate:      startDate,
            endDate:        endDate,
            notes:          notes,
            genre:          genre,
            tags:           tags,
            coverImageData: coverImageData,
            openLibraryKey: openLibraryKey,
            isbn:           isbn.isEmpty ? nil : isbn
        )
    }

    private func applyChanges(to item: inout ReadingItem) {
        item.title          = title.trimmingCharacters(in: .whitespaces)
        item.contentType    = contentType
        item.author         = author
        item.illustrator    = illustrator
        item.publisher      = publisher
        item.volume         = Int(volume)
        item.issueNumber    = Int(issueNumber)
        item.chapter        = Int(chapter)
        item.edition        = edition
        item.status         = status
        item.rating         = rating
        item.isFavorite     = isFavorite
        item.startDate      = startDate
        item.endDate        = endDate
        item.notes          = notes
        item.genre          = genre
        item.tags           = tags
        item.openLibraryKey = openLibraryKey
        item.isbn           = isbn.isEmpty ? nil : isbn
        item.updatedAt      = Date()
        if let d = coverImageData { item.coverImageData = d }
    }

    // MARK: - Tags

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

    func searchMetadata(googleBooksKey: String = "", comicVineKey: String = "") async {
        isSearchingMetadata = true
        metadataError = nil
        defer { isSearchingMetadata = false }
        do {
            metadataResults = try await MediaSearchService.shared.search(
                query:             metadataSearchQuery,
                source:            selectedSource,
                contentType:       contentType,
                googleBooksAPIKey: googleBooksKey,
                comicVineAPIKey:   comicVineKey
            )
        } catch {
            metadataError = error.localizedDescription
            metadataResults = []
        }
    }

    func applyMetadata(_ result: MediaSearchResult) async {
        title     = result.title
        author    = result.subtitle
        publisher = result.secondaryInfo.isEmpty
                    ? (result.extraInfo["publisher"] ?? "")
                    : result.secondaryInfo
        isbn      = result.isbn ?? ""

        if let artists = result.extraInfo["artists"], !artists.isEmpty {
            illustrator = artists
        }
        for t in result.tags.prefix(5) where !tags.contains(t) {
            tags.append(t)
        }
        contentType = result.contentType

        if let url = result.coverURL {
            let source = resolvedSource(for: result)
            if let data = await MediaSearchService.shared.fetchCoverData(
                from: url, source: source
            ) {
                coverImageData = ImageService.processImage(data)
            }
        }
        metadataResults = []
    }

    private func resolvedSource(for result: MediaSearchResult) -> SearchSource {
        if result.id.hasPrefix("gb_") { return .googleBooks }
        if result.id.hasPrefix("md_") { return .mangaDex }
        if result.id.hasPrefix("cv_") { return .comicVine }
        return .auto
    }
}
