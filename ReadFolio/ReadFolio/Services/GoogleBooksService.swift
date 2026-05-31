//
//  GoogleBooksResult.swift
//  ReadFolio
//
//  Created by Christian Lo Conte on 31/05/2026.
//


import Foundation

// MARK: - Result Model

struct GoogleBooksResult: Identifiable, Sendable {
    let id: String              // volumeId Google
    let title: String
    let authors: [String]
    let publisher: String
    let publishedDate: String
    let description: String
    let isbn13: String?
    let isbn10: String?
    let pageCount: Int?
    let categories: [String]
    let coverURL: URL?
    let language: String
}

// MARK: - Errors

enum GoogleBooksError: LocalizedError {
    case invalidQuery
    case networkError(Error)
    case decodingError(String)
    case noResults
    case apiError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidQuery:          return "Inserisci almeno 2 caratteri per cercare."
        case .networkError(let e):   return "Errore di rete: \(e.localizedDescription)"
        case .decodingError(let d):  return "Errore nel leggere la risposta: \(d)"
        case .noResults:             return "Nessun libro trovato."
        case .apiError(let code):    return "Errore API Google Books (codice \(code))."
        }
    }
}

// MARK: - Service

actor GoogleBooksService {
    static let shared = GoogleBooksService()
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Search

    /// Cerca libri per titolo, autore, ISBN o query generica.
    func search(query: String, startIndex: Int = 0) async throws -> [GoogleBooksResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { throw GoogleBooksError.invalidQuery }

        var components = URLComponents(string: "\(Constants.GoogleBooks.baseURL)/volumes")!
        components.queryItems = [
            URLQueryItem(name: "q",           value: trimmed),
            URLQueryItem(name: "maxResults",  value: "\(Constants.GoogleBooks.maxResults)"),
            URLQueryItem(name: "startIndex",  value: "\(startIndex)"),
            URLQueryItem(name: "printType",   value: "books"),
            URLQueryItem(name: "langRestrict",value: "it"),   // preferisce risultati in italiano
            URLQueryItem(name: "key",         value: Constants.APIKeys.googleBooks)
        ]

        guard let url = components.url else { throw GoogleBooksError.decodingError("URL non valido") }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw GoogleBooksError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw GoogleBooksError.apiError(http.statusCode)
        }

        return try parseVolumes(from: data)
    }

    /// Cerca per ISBN (più preciso).
    func searchByISBN(_ isbn: String) async throws -> GoogleBooksResult? {
        let results = try await search(query: "isbn:\(isbn)")
        return results.first
    }

    // MARK: - Cover

    func fetchCoverData(from url: URL) async -> Data? {
        try? await session.data(from: url).0
    }

    // MARK: - Parsing

    private func parseVolumes(from data: Data) throws -> [GoogleBooksResult] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw GoogleBooksError.decodingError("JSON malformato")
        }

        // totalItems == 0 → nessun risultato
        if let total = json["totalItems"] as? Int, total == 0 {
            throw GoogleBooksError.noResults
        }

        guard let items = json["items"] as? [[String: Any]] else {
            throw GoogleBooksError.noResults
        }

        return items.compactMap { item -> GoogleBooksResult? in
            guard
                let volumeId = item["id"] as? String,
                let info     = item["volumeInfo"] as? [String: Any],
                let title    = info["title"] as? String
            else { return nil }

            let authors   = info["authors"]    as? [String] ?? []
            let publisher = info["publisher"]  as? String  ?? ""
            let published = info["publishedDate"] as? String ?? ""
            let desc      = info["description"] as? String ?? ""
            let pages     = info["pageCount"]  as? Int
            let categories = info["categories"] as? [String] ?? []
            let language  = info["language"]   as? String ?? ""

            // ISBN
            var isbn13: String? = nil
            var isbn10: String? = nil
            if let identifiers = info["industryIdentifiers"] as? [[String: Any]] {
                for idf in identifiers {
                    let type = idf["type"] as? String ?? ""
                    let id   = idf["identifier"] as? String ?? ""
                    if type == "ISBN_13" { isbn13 = id }
                    if type == "ISBN_10" { isbn10 = id }
                }
            }

            // Cover — preferiamo HTTPS e dimensione più grande
            var coverURL: URL? = nil
            if let imageLinks = info["imageLinks"] as? [String: Any] {
                // Prova in ordine di preferenza: large > medium > thumbnail
                let keys = ["large", "medium", "thumbnail", "smallThumbnail"]
                for key in keys {
                    if let raw = imageLinks[key] as? String {
                        // Google Books restituisce spesso http:// — forziamo https
                        let https = raw.replacingOccurrences(of: "http://", with: "https://")
                        coverURL = URL(string: https)
                        break
                    }
                }
            }

            return GoogleBooksResult(
                id:           volumeId,
                title:        title,
                authors:      authors,
                publisher:    publisher,
                publishedDate: published,
                description:  desc,
                isbn13:       isbn13,
                isbn10:       isbn10,
                pageCount:    pages,
                categories:   categories,
                coverURL:     coverURL,
                language:     language
            )
        }
    }
}
