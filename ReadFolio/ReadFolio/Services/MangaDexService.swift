//
//  MangaDexResult.swift
//  ReadFolio
//
//  Created by Christian Lo Conte on 31/05/2026.
//


import Foundation

// MARK: - Result Model

struct MangaDexResult: Identifiable, Sendable {
    let id: String              // UUID MangaDex
    let title: String           // titolo in italiano se disponibile, altrimenti inglese
    let titleOriginal: String   // titolo in lingua originale (giapponese/coreano/ecc.)
    let authors: [String]
    let artists: [String]       // illustratori
    let description: String
    let status: String          // ongoing, completed, hiatus, cancelled
    let year: Int?
    let tags: [String]
    let contentRating: String   // safe, suggestive, erotica, pornographic
    let originalLanguage: String   // ← aggiungi questa riga
    let coverURL: URL?
    let chapters: Int?          // numero totale capitoli se disponibile
}

enum MangaDexError: LocalizedError {
    case invalidQuery
    case networkError(Error)
    case decodingError
    case noResults
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidQuery:  return "Inserisci almeno 2 caratteri per cercare."
        case .networkError(let e): return "Errore di rete: \(e.localizedDescription)"
        case .decodingError: return "Errore nel leggere la risposta MangaDex."
        case .noResults:     return "Nessun manga trovato."
        case .rateLimited:   return "Troppe richieste. Riprova tra qualche secondo."
        }
    }
}

// MARK: - Service

actor MangaDexService {
    static let shared = MangaDexService()
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        // MangaDex richiede User-Agent non vuoto
        config.httpAdditionalHeaders = ["User-Agent": "Readfolio/1.0"]
        session = URLSession(configuration: config)
    }

    // MARK: - Search

    func search(query: String) async throws -> [MangaDexResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { throw MangaDexError.invalidQuery }

        var components = URLComponents(string: "\(Constants.MangaDex.baseURL)/manga")!
        components.queryItems = [
            URLQueryItem(name: "title",                    value: trimmed),
            URLQueryItem(name: "limit",                    value: "\(Constants.MangaDex.maxResults)"),
            URLQueryItem(name: "offset",                   value: "0"),
            // Includi le relazioni necessarie in una sola chiamata
            URLQueryItem(name: "includes[]",               value: "author"),
            URLQueryItem(name: "includes[]",               value: "artist"),
            URLQueryItem(name: "includes[]",               value: "cover_art"),
            // Escludi contenuti espliciti per default
            URLQueryItem(name: "contentRating[]",          value: "safe"),
            URLQueryItem(name: "contentRating[]",          value: "suggestive"),
            URLQueryItem(name: "availableTranslatedLanguage[]", value: "it"),
        ]

        guard let url = components.url else { throw MangaDexError.decodingError }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw MangaDexError.networkError(error)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw MangaDexError.rateLimited }
            if http.statusCode != 200 { throw MangaDexError.decodingError }
        }

        return try parseManga(from: data)
    }

    // MARK: - Cover

    func fetchCoverData(from url: URL) async -> Data? {
        try? await session.data(from: url).0
    }

    // MARK: - Parsing

    private func parseManga(from data: Data) throws -> [MangaDexResult] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dataArr = json["data"] as? [[String: Any]]
        else { throw MangaDexError.decodingError }

        if dataArr.isEmpty { throw MangaDexError.noResults }

        return dataArr.compactMap { item -> MangaDexResult? in
            guard
                let mangaId    = item["id"] as? String,
                let attributes = item["attributes"] as? [String: Any]
            else { return nil }

            // Titolo: preferisce italiano, poi inglese, poi primo disponibile
            let title = extractLocalizedTitle(from: attributes["title"] as? [String: Any] ?? [:])
            let titleOriginal = (attributes["title"] as? [String: Any])?["ja"] as? String
                             ?? (attributes["title"] as? [String: Any])?["ja-ro"] as? String
                             ?? title

            // Descrizione
            let desc = extractLocalizedString(
                from: attributes["description"] as? [String: Any] ?? [:],
                fallback: ""
            )

            let status        = attributes["status"]        as? String ?? ""
            let year          = attributes["year"]          as? Int
            let contentRating = attributes["contentRating"] as? String ?? "safe"

            // Capitoli (lastChapter se disponibile)
            let chaptersStr = attributes["lastChapter"] as? String
            let chapters    = chaptersStr.flatMap { Int($0) }

            // Tags
            let tagObjects = attributes["tags"] as? [[String: Any]] ?? []
            let tags: [String] = tagObjects.compactMap { tag in
                guard
                    let tagAttr = tag["attributes"] as? [String: Any],
                    let names   = tagAttr["name"] as? [String: Any]
                else { return nil }
                return names["en"] as? String
            }

            // Relationships
            let relationships = item["relationships"] as? [[String: Any]] ?? []
            var authors: [String] = []
            var artists: [String] = []
            var coverFileName: String? = nil

            for rel in relationships {
                let type = rel["type"] as? String ?? ""
                let relAttr = rel["attributes"] as? [String: Any] ?? [:]
                let name = relAttr["name"] as? String ?? ""

                switch type {
                case "author": if !name.isEmpty { authors.append(name) }
                case "artist": if !name.isEmpty { artists.append(name) }
                case "cover_art":
                    coverFileName = relAttr["fileName"] as? String
                default: break
                }
            }

            // Cover URL
            var coverURL: URL? = nil
            if let fileName = coverFileName {
                // Format: /covers/{mangaId}/{fileName}.256.jpg (thumbnail)
                let urlString = "\(Constants.MangaDex.coversURL)/\(mangaId)/\(fileName).256.jpg"
                coverURL = URL(string: urlString)
            }

            return MangaDexResult(
                id:            mangaId,
                title:         title,
                titleOriginal: titleOriginal,
                authors:       authors,
                artists:       artists,
                description:   desc,
                status:        status,
                year:          year,
                tags:          tags,
                contentRating: contentRating,
                coverURL:      coverURL,
                chapters:      chapters
            )
        }
    }

    private func extractLocalizedTitle(from dict: [String: Any]) -> String {
        // Priorità: italiano → inglese → romanizzazione giapponese → primo disponibile
        if let it  = dict["it"] as? String,  !it.isEmpty  { return it }
        if let en  = dict["en"] as? String,  !en.isEmpty  { return en }
        if let jaRo = dict["ja-ro"] as? String, !jaRo.isEmpty { return jaRo }
        return dict.values.compactMap { $0 as? String }.first ?? "Titolo sconosciuto"
    }

    private func extractLocalizedString(from dict: [String: Any], fallback: String) -> String {
        if let it = dict["it"] as? String, !it.isEmpty { return it }
        if let en = dict["en"] as? String, !en.isEmpty { return en }
        return dict.values.compactMap { $0 as? String }.first ?? fallback
    }
}
