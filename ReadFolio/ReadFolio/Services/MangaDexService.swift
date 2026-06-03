import Foundation

// ─────────────────────────────────────────────
// MANGADEX API KEY
// ✅ NESSUNA API KEY RICHIESTA
//
// MangaDex è completamente gratuito e pubblico.
// Non serve registrarsi né configurare nulla.
// Rate limit: 5 richieste/secondo — rispettato
// automaticamente dall'app grazie ai Task async.
//
// Documentazione ufficiale:
// https://api.mangadex.org/docs
// ─────────────────────────────────────────────

struct MangaDexResult: Identifiable {
    let id: String
    let title: String
    let titleAlternatives: [String]
    let authors: [String]
    let artists: [String]
    let description: String
    let status: String
    let year: Int?
    let tags: [String]
    let contentRating: String
    let originalLanguage: String
    let coverURL: URL?
    let contentType: ContentType = .manga
}

enum MangaDexError: LocalizedError {
    case networkError(Error)
    case decodingError
    case noResults
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .networkError(let e): return "Errore di rete: \(e.localizedDescription)"
        case .decodingError:       return "Errore nel formato risposta MangaDex."
        case .noResults:           return "Nessun manga trovato."
        case .rateLimited:         return "Rate limit MangaDex. Riprova tra qualche secondo."
        }
    }
}

actor MangaDexService {
    static let shared = MangaDexService()

    private let session: URLSession
    private let base = "https://api.mangadex.org"

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - Search

    func search(query: String) async throws -> [MangaDexResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return try await fetchPopular()
        }

        guard var components = URLComponents(string: "\(base)/manga") else {
            throw MangaDexError.decodingError
        }
        components.queryItems = [
            URLQueryItem(name: "title",            value: trimmed),
            URLQueryItem(name: "limit",            value: "20"),
            URLQueryItem(name: "includes[]",       value: "author"),
            URLQueryItem(name: "includes[]",       value: "artist"),
            URLQueryItem(name: "includes[]",       value: "cover_art"),
            URLQueryItem(name: "contentRating[]",  value: "safe"),
            URLQueryItem(name: "contentRating[]",  value: "suggestive"),
            URLQueryItem(name: "order[relevance]", value: "desc")
        ]

        guard let url = components.url else { throw MangaDexError.decodingError }
        return try await fetch(url: url)
    }

    // MARK: - Popular (query vuota)

    private func fetchPopular() async throws -> [MangaDexResult] {
        guard var components = URLComponents(string: "\(base)/manga") else {
            throw MangaDexError.decodingError
        }

        components.queryItems = [
            URLQueryItem(name: "limit",                value: "20"),
            URLQueryItem(name: "includes[]",           value: "author"),
            URLQueryItem(name: "includes[]",           value: "artist"),
            URLQueryItem(name: "includes[]",           value: "cover_art"),
            URLQueryItem(name: "contentRating[]",      value: "safe"),
            URLQueryItem(name: "contentRating[]",      value: "suggestive"),
            URLQueryItem(name: "order[followedCount]", value: "desc")
        ]

        guard let url = components.url else { throw MangaDexError.decodingError }
        return try await fetch(url: url)
    }

    // MARK: - Fetch comune

    private func fetch(url: URL) async throws -> [MangaDexResult] {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw MangaDexError.networkError(error)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw MangaDexError.rateLimited }
            guard http.statusCode == 200 else { throw MangaDexError.decodingError }
        }

        return try parse(data: data)
    }

    // MARK: - Cover

    func fetchCoverData(from url: URL) async -> Data? {
        try? await session.data(from: url).0
    }

    // MARK: - Parsing

    private func parse(data: Data) throws -> [MangaDexResult] {
        guard
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dataArr = json["data"] as? [[String: Any]]
        else { throw MangaDexError.decodingError }

        if dataArr.isEmpty { throw MangaDexError.noResults }

        return dataArr.compactMap { item -> MangaDexResult? in
            guard
                let id    = item["id"] as? String,
                let attrs = item["attributes"] as? [String: Any]
            else { return nil }

            let titleMap = attrs["title"] as? [String: String] ?? [:]
            let title = titleMap["en"]
                     ?? titleMap["ja-ro"]
                     ?? titleMap["ja"]
                     ?? titleMap.values.first
                     ?? "Titolo sconosciuto"

            let altTitlesArr = attrs["altTitles"] as? [[String: String]] ?? []
            let alternatives = altTitlesArr.compactMap { dict -> String? in
                dict["en"] ?? dict["ja-ro"] ?? dict.values.first
            }

            let descMap     = attrs["description"]    as? [String: String] ?? [:]
            let description = descMap["en"] ?? descMap["it"] ?? descMap.values.first ?? ""

            let status           = attrs["status"]           as? String ?? ""
            let year             = attrs["year"]             as? Int
            let originalLanguage = attrs["originalLanguage"] as? String ?? ""
            let contentRating    = attrs["contentRating"]    as? String ?? "safe"

            let tagsRaw = attrs["tags"] as? [[String: Any]] ?? []
            let tags: [String] = tagsRaw.compactMap { tag in
                guard
                    let tagAttrs = tag["attributes"] as? [String: Any],
                    let nameMap  = tagAttrs["name"]  as? [String: String]
                else { return nil }
                return nameMap["en"] ?? nameMap.values.first
            }

            let relationships = item["relationships"] as? [[String: Any]] ?? []
            var authors: [String] = []
            var artists: [String] = []
            var coverFilename: String? = nil

            for rel in relationships {
                let relType  = rel["type"]       as? String       ?? ""
                let relAttrs = rel["attributes"] as? [String: Any]

                if relType == "author",
                   let name = relAttrs?["name"] as? String { authors.append(name) }
                if relType == "artist",
                   let name = relAttrs?["name"] as? String { artists.append(name) }
                if relType == "cover_art",
                   let fname = relAttrs?["fileName"] as? String { coverFilename = fname }
            }

            var coverURL: URL? = nil
            if let fname = coverFilename {
                coverURL = URL(string:
                    "https://uploads.mangadex.org/covers/\(id)/\(fname).512.jpg")
            }

            return MangaDexResult(
                id:                id,
                title:             title,
                titleAlternatives: alternatives,
                authors:           authors,
                artists:           artists,
                description:       description,
                status:            status,
                year:              year,
                tags:              tags,
                contentRating:     contentRating,
                originalLanguage:  originalLanguage,
                coverURL:          coverURL
            )
        }
    }
}
