import Foundation
import SwiftData

@Model
final class ReadingItem {
    // MARK: - Identity
    var title: String
    var contentType: ContentType

    // MARK: - Creators
    var author: String
    var illustrator: String
    var publisher: String

    // MARK: - Publication info
    var volume: Int?
    var issueNumber: Int?
    var chapter: Int?
    var edition: String

    // MARK: - Reading state
    var status: ReadingStatus
    var rating: Int          // 0 = non valutato, 1-5
    var isFavorite: Bool
    var startDate: Date?
    var endDate: Date?
    var notes: String

    // MARK: - Metadata
    var genre: String
    var tags: [Tag]
    var coverImageData: Data?

    // MARK: - Timestamps
    var createdAt: Date
    var updatedAt: Date

    // MARK: - External IDs (per future integrazioni)
    var openLibraryKey: String?
    var isbn: String?

    init(
        title: String,
        contentType: ContentType = .book,
        author: String = "",
        illustrator: String = "",
        publisher: String = "",
        volume: Int? = nil,
        issueNumber: Int? = nil,
        chapter: Int? = nil,
        edition: String = "",
        status: ReadingStatus = .toRead,
        rating: Int = 0,
        isFavorite: Bool = false,
        startDate: Date? = nil,
        endDate: Date? = nil,
        notes: String = "",
        genre: String = "",
        tags: [Tag] = [],
        coverImageData: Data? = nil,
        openLibraryKey: String? = nil,
        isbn: String? = nil
    ) {
        self.title = title
        self.contentType = contentType
        self.author = author
        self.illustrator = illustrator
        self.publisher = publisher
        self.volume = volume
        self.issueNumber = issueNumber
        self.chapter = chapter
        self.edition = edition
        self.status = status
        self.rating = rating
        self.isFavorite = isFavorite
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.genre = genre
        self.tags = tags
        self.coverImageData = coverImageData
        self.openLibraryKey = openLibraryKey
        self.isbn = isbn
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func duplicate() -> ReadingItem {
        ReadingItem(
            title: title + " (copia)",
            contentType: contentType,
            author: author,
            illustrator: illustrator,
            publisher: publisher,
            volume: volume,
            issueNumber: issueNumber,
            chapter: chapter,
            edition: edition,
            status: .toRead,
            rating: 0,
            isFavorite: false,
            notes: notes,
            genre: genre,
            tags: tags,
            coverImageData: coverImageData,
            openLibraryKey: openLibraryKey,
            isbn: isbn
        )
    }
}
