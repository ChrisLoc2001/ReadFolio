import Foundation

struct MediaSearchResult: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let secondaryInfo: String
    let description: String
    let year: String
    let tags: [String]
    let isbn: String?
    let coverURL: URL?
    let contentType: ContentType
    let sourceID: String
    let extraInfo: [String: String]
}

enum SearchSource: String, CaseIterable, Identifiable {
    case googleBooks = "Google Books"
    case mangaDex    = "MangaDex"
    case comicVine   = "Comic Vine"
    case auto        = "Automatico"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .googleBooks: return "book.fill"
        case .mangaDex:    return "doc.text.image.fill"
        case .comicVine:   return "rectangle.stack.fill"
        case .auto:        return "magnifyingglass"
        }
    }
}

enum MediaSearchError: LocalizedError {
    case noSource
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .noSource:          return "Nessuna sorgente disponibile per questo tipo di contenuto."
        case .underlying(let e): return e.localizedDescription
        }
    }
}

actor MediaSearchService {
    static let shared = MediaSearchService()

    // MARK: - Search

    func search(
        query: String,
        source: SearchSource,
        contentType: ContentType,
        googleBooksAPIKey: String = "",
        comicVineAPIKey: String = ""
    ) async throws -> [MediaSearchResult] {

        let effectiveSource = resolveSource(source: source, contentType: contentType)

        switch effectiveSource {
        case .googleBooks:
            let results = try await GoogleBooksService.shared.search(query: query)
            return results.map { normalize(book: $0) }

        case .mangaDex:
            let results = try await MangaDexService.shared.search(query: query)
            return results.map { normalize(manga: $0) }

        case .comicVine:
            let results = try await ComicVineService.shared.searchVolumes(
                query: query,
                apiKey: comicVineAPIKey
            )
            return results.map { normalize(comic: $0) }

        case .auto:
            throw MediaSearchError.noSource
        }
    }

    func fetchCoverData(from url: URL, source: SearchSource) async -> Data? {
        switch source {
        case .googleBooks: return await GoogleBooksService.shared.fetchCoverData(from: url)
        case .mangaDex:    return await MangaDexService.shared.fetchCoverData(from: url)
        case .comicVine:   return await ComicVineService.shared.fetchCoverData(from: url)
        case .auto:        return try? await URLSession.shared.data(from: url).0
        }
    }

    // MARK: - Source resolution

    private func resolveSource(source: SearchSource, contentType: ContentType) -> SearchSource {
        guard source == .auto else { return source }
        switch contentType {
        case .book:  return .googleBooks
        case .manga: return .mangaDex
        case .comic: return .comicVine
        }
    }

    // MARK: - Normalizers

    private func normalize(book: GoogleBooksResult) -> MediaSearchResult {
        MediaSearchResult(
            id:            "gb_\(book.id)",
            title:         book.title,
            subtitle:      book.authors.joined(separator: ", "),
            secondaryInfo: book.publisher,
            description:   book.description,
            year:          String(book.publishedDate.prefix(4)),
            tags:          book.categories,
            isbn:          book.isbn13 ?? book.isbn10,
            coverURL:      book.coverURL,
            contentType:   .book,
            sourceID:      book.id,
            extraInfo: [
                "pageCount": book.pageCount.map(String.init) ?? "",
                "language":  book.language,
                "isbn13":    book.isbn13 ?? "",
                "isbn10":    book.isbn10 ?? ""
            ]
        )
    }

    private func normalize(manga: MangaDexResult) -> MediaSearchResult {
        MediaSearchResult(
            id:            "md_\(manga.id)",
            title:         manga.title,
            subtitle:      manga.authors.joined(separator: ", "),
            secondaryInfo: manga.status.capitalized,
            description:   manga.description,
            year:          manga.year.map(String.init) ?? "",
            tags:          manga.tags,
            isbn:          nil,
            coverURL:      manga.coverURL,
            contentType:   .manga,
            sourceID:      manga.id,
            extraInfo: [
                "artists":          manga.artists.joined(separator: ", "),
                "originalLanguage": manga.originalLanguage,
                "contentRating":    manga.contentRating,
                "status":           manga.status
            ]
        )
    }

    private func normalize(comic: ComicVineResult) -> MediaSearchResult {
        MediaSearchResult(
            id:            "cv_\(comic.id)",
            title:         comic.name,
            subtitle:      comic.publisher,
            secondaryInfo: comic.startYear.map { "Dal \($0)" } ?? "",
            description:   comic.description,
            year:          comic.startYear ?? "",
            tags:          [],
            isbn:          nil,
            coverURL:      comic.coverURL,
            contentType:   .comic,
            sourceID:      String(comic.id),
            extraInfo: [
                "issueCount":  comic.issueCount.map(String.init) ?? "",
                "issueNumber": comic.issueNumber ?? "",
                "startYear":   comic.startYear ?? ""
            ]
        )
    }
}
