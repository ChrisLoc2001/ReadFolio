import Foundation

struct ReadingItem: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var contentType: ContentType
    var author: String
    var illustrator: String
    var publisher: String
    var volume: Int?
    var issueNumber: Int?
    var chapter: Int?
    var edition: String
    var status: ReadingStatus
    var rating: Int
    var isFavorite: Bool
    var startDate: Date?
    var endDate: Date?
    var notes: String
    var genre: String
    var tags: [String]
    /// Copertina su Firebase Storage (download URL). È ciò che viene persistito.
    var coverImageURL: String?
    /// Copertina locale appena scelta dall'utente, NON ancora caricata.
    /// Transitoria: esclusa da Codable per non finire dentro il documento Firestore
    /// (evita il limite di 1 MiB e il download di blob ad ogni fetch).
    var coverImageData: Data? = nil
    var openLibraryKey: String?
    var isbn: String?
    var createdAt: Date
    var updatedAt: Date
    var userID: String

    // coverImageData è volutamente assente: non viene serializzato su Firestore.
    private enum CodingKeys: String, CodingKey {
        case id, title, contentType, author, illustrator, publisher, volume,
             issueNumber, chapter, edition, status, rating, isFavorite,
             startDate, endDate, notes, genre, tags, coverImageURL,
             openLibraryKey, isbn, createdAt, updatedAt, userID
    }

    init(
        id: String = UUID().uuidString,
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
        tags: [String] = [],
        coverImageURL: String? = nil,
        coverImageData: Data? = nil,
        openLibraryKey: String? = nil,
        isbn: String? = nil,
        userID: String = ""
    ) {
        self.id            = id
        self.title         = title
        self.contentType   = contentType
        self.author        = author
        self.illustrator   = illustrator
        self.publisher     = publisher
        self.volume        = volume
        self.issueNumber   = issueNumber
        self.chapter       = chapter
        self.edition       = edition
        self.status        = status
        self.rating        = rating
        self.isFavorite    = isFavorite
        self.startDate     = startDate
        self.endDate       = endDate
        self.notes         = notes
        self.genre         = genre
        self.tags          = tags
        self.coverImageURL  = coverImageURL
        self.coverImageData = coverImageData
        self.openLibraryKey = openLibraryKey
        self.isbn          = isbn
        self.createdAt     = Date()
        self.updatedAt     = Date()
        self.userID        = userID
    }

    func duplicate() -> ReadingItem {
        ReadingItem(
            title:         title + " (copia)",
            contentType:   contentType,
            author:        author,
            illustrator:   illustrator,
            publisher:     publisher,
            volume:        volume,
            issueNumber:   issueNumber,
            chapter:       chapter,
            edition:       edition,
            status:        .toRead,
            rating:        0,
            isFavorite:    false,
            notes:         notes,
            genre:         genre,
            tags:          tags,
            coverImageURL: coverImageURL,
            coverImageData: coverImageData,
            openLibraryKey: openLibraryKey,
            isbn:          isbn,
            userID:        userID
        )
    }
}
