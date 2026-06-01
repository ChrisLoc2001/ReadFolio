import Foundation

// ─────────────────────────────────────────────
// GOOGLE BOOKS API KEY
// Ottieni la tua chiave gratuita su:
// https://console.cloud.google.com
//
// Passaggi:
// 1. Crea un progetto
// 2. Vai su "API e servizi" → "Libreria"
// 3. Cerca "Books API" e abilitala
// 4. Vai su "Credenziali" → "Crea credenziali" → "Chiave API"
// 5. Sostituisci il valore qui sotto con la tua chiave
//
// Senza key:  ~100 richieste/giorno
// Con key:   1000 richieste/giorno (gratuito)
// ─────────────────────────────────────────────
private nonisolated var googleBooksAPIKey: String {
    Bundle.main.infoDictionary?["GoogleBooksAPIKey"] as? String ?? ""
}

struct GoogleBooksResult: Identifiable {
    let id: String
    let title: String
    let authors: [String]
    let publisher: String
    let publishedDate: String
    let description: String
    let isbn13: String?
    let isbn10: String?
    let pageCount: Int?
    let categories: [String]
    let language: String
    let coverURL: URL?
    let contentType: ContentType = .book
}

enum GoogleBooksError: LocalizedError {
    case networkError(Error)
    case decodingError(String)
    case noResults
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .networkError(let e):  return "Errore di rete: \(e.localizedDescription)"
        case .decodingError(let d): return "Errore nel formato risposta: \(d)"
        case .noResults:            return "Nessun libro trovato."
        case .rateLimited:          return "Troppe richieste. Riprova tra qualche secondo."
        }
    }
}

actor GoogleBooksService {
    static let shared = GoogleBooksService()

    private let session: URLSession
    private let base = "https://www.googleapis.com/books/v1"
    private let defaultQuery = "subject:fiction"

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Search

    func search(query: String) async throws -> [GoogleBooksResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let effectiveQuery = trimmed.isEmpty ? defaultQuery : trimmed

        guard var components = URLComponents(string: "\(base)/volumes") else {
            throw GoogleBooksError.decodingError("URL base non valido")
        }
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q",          value: effectiveQuery),
            URLQueryItem(name: "maxResults", value: "20"),
            URLQueryItem(name: "printType",  value: "books"),
            URLQueryItem(name: "orderBy",    value: "relevance"),
            URLQueryItem(name: "fields",
                         value: "items(id,volumeInfo(title,authors,publisher,publishedDate,description,industryIdentifiers,pageCount,categories,language,imageLinks))")
        ]

        // Aggiunge la key solo se è stata configurata
        if !googleBooksAPIKey.isEmpty && googleBooksAPIKey != "[INSERISCI LA TUA API KEY QUI]" {
            queryItems.append(URLQueryItem(name: "key", value: googleBooksAPIKey))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw GoogleBooksError.decodingError("URL non valido")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw GoogleBooksError.networkError(error)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw GoogleBooksError.rateLimited }
            guard http.statusCode == 200 else {
                throw GoogleBooksError.decodingError("HTTP \(http.statusCode)")
            }
        }

        return try parseSearch(data: data)
    }

    // MARK: - Cover

    func fetchCoverData(from url: URL) async -> Data? {
        var httpsURL = url
        if url.scheme == "http" {
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            comps.scheme = "https"
            httpsURL = comps.url ?? url
        }
        return try? await session.data(from: httpsURL).0
    }

    // MARK: - Parsing

    private func parseSearch(data: Data) throws -> [GoogleBooksResult] {
        guard
            let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = json["items"] as? [[String: Any]]
        else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let total = json["totalItems"] as? Int, total == 0 {
                throw GoogleBooksError.noResults
            }
            throw GoogleBooksError.decodingError("Struttura JSON inattesa")
        }

        if items.isEmpty { throw GoogleBooksError.noResults }

        return items.compactMap { item -> GoogleBooksResult? in
            guard
                let id    = item["id"] as? String,
                let info  = item["volumeInfo"] as? [String: Any],
                let title = info["title"] as? String
            else { return nil }

            let authors       = info["authors"]       as? [String] ?? []
            let publisher     = info["publisher"]     as? String   ?? ""
            let publishedDate = info["publishedDate"] as? String   ?? ""
            let description   = info["description"]  as? String   ?? ""
            let pageCount     = info["pageCount"]     as? Int
            let categories    = info["categories"]   as? [String] ?? []
            let language      = info["language"]     as? String   ?? ""

            var isbn13: String? = nil
            var isbn10: String? = nil
            if let identifiers = info["industryIdentifiers"] as? [[String: Any]] {
                for idf in identifiers {
                    let type       = idf["type"]       as? String ?? ""
                    let identifier = idf["identifier"] as? String ?? ""
                    if type == "ISBN_13" { isbn13 = identifier }
                    if type == "ISBN_10" { isbn10 = identifier }
                }
            }

            var coverURL: URL? = nil
            if let imageLinks = info["imageLinks"] as? [String: Any] {
                let urlString = imageLinks["thumbnail"] as? String
                             ?? imageLinks["smallThumbnail"] as? String
                if let s = urlString {
                    let cleaned = s
                        .replacingOccurrences(of: "&zoom=1", with: "&zoom=2")
                        .replacingOccurrences(of: "http://", with: "https://")
                    coverURL = URL(string: cleaned)
                }
            }

            return GoogleBooksResult(
                id:            id,
                title:         title,
                authors:       authors,
                publisher:     publisher,
                publishedDate: publishedDate,
                description:   description,
                isbn13:        isbn13,
                isbn10:        isbn10,
                pageCount:     pageCount,
                categories:    categories,
                language:      language,
                coverURL:      coverURL
            )
        }
    }
}
