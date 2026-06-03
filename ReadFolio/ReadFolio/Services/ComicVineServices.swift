import Foundation

// ─────────────────────────────────────────────
// COMIC VINE API KEY (obbligatoria per questa sorgente)
// Si ottiene su https://comicvine.gamespot.com/api e si configura in
// Secrets.xcconfig (COMIC_VINE_API_KEY). Letta centralmente da AppConfig.
// ─────────────────────────────────────────────

struct ComicVineResult: Identifiable {
    let id: Int
    let name: String
    let issueNumber: String?
    let description: String
    let publisher: String
    let startYear: String?
    let coverURL: URL?
    let issueCount: Int?
    let contentType: ContentType = .comic
}

enum ComicVineError: LocalizedError {
    case missingAPIKey
    case networkError(Error)
    case decodingError
    case noResults
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key Comic Vine non configurata. Inseriscila in Secrets.xcconfig (COMIC_VINE_API_KEY)."
        case .networkError(let e):
            return "Errore di rete: \(e.localizedDescription)"
        case .decodingError:
            return "Errore nel formato risposta Comic Vine."
        case .noResults:
            return "Nessun fumetto trovato."
        case .apiError(let msg):
            return "Errore API: \(msg)"
        }
    }
}

actor ComicVineService {
    static let shared = ComicVineService()

    private let session: URLSession
    private let userAgent = "Readfolio/1.0 (iOS/macOS App)"
    private let base = "https://comicvine.gamespot.com/api"

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = [
            "User-Agent": "Readfolio/1.0 (iOS/macOS App)",
            "Accept": "application/json"
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Validazione key

    private func validatedKey() throws -> String {
        guard AppConfig.isComicVineConfigured else {
            throw ComicVineError.missingAPIKey
        }
        return AppConfig.comicVineAPIKey
    }

    // MARK: - Search Volumes

    func searchVolumes(query: String) async throws -> [ComicVineResult] {
        let key = try validatedKey()
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return try await fetchPopular(apiKey: key)
        }

        guard var components = URLComponents(string: "\(base)/search/") else {
            throw ComicVineError.decodingError
        }

        components.queryItems = [
            URLQueryItem(name: "apikey",    value: key),
            URLQueryItem(name: "format",    value: "json"),
            URLQueryItem(name: "query",     value: trimmed),
            URLQueryItem(name: "resources", value: "volume"),
            URLQueryItem(name: "limit",     value: "20"),
            URLQueryItem(name: "fieldlist",
                         value: "id,name,description,publisher,startyear,image,countofissues")
        ]

        guard let url = components.url else { throw ComicVineError.decodingError }
        return try await fetch(url: url)
    }

    // MARK: - Popular (query vuota)

    private func fetchPopular(apiKey: String) async throws -> [ComicVineResult] {
        guard var components = URLComponents(string: "\(base)/volumes/") else {
            throw ComicVineError.decodingError
        }

        components.queryItems = [
            URLQueryItem(name: "apikey",    value: apiKey),
            URLQueryItem(name: "format",    value: "json"),
            URLQueryItem(name: "limit",     value: "20"),
            URLQueryItem(name: "sort",      value: "count_of_issues:desc"),
            URLQueryItem(name: "fieldlist",
                         value: "id,name,description,publisher,startyear,image,countofissues")
        ]

        guard let url = components.url else { throw ComicVineError.decodingError }
        return try await fetch(url: url)
    }

    // MARK: - Fetch comune

    private func fetch(url: URL) async throws -> [ComicVineResult] {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ComicVineError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ComicVineError.decodingError
        }

        return try parseVolumes(data: data)
    }

    // MARK: - Search Issues

    func searchIssues(query: String) async throws -> [ComicVineResult] {
        let key = try validatedKey()

        guard var components = URLComponents(string: "\(base)/search/") else {
            throw ComicVineError.decodingError
        }
        components.queryItems = [
            URLQueryItem(name: "apikey",    value: key),
            URLQueryItem(name: "format",    value: "json"),
            URLQueryItem(name: "query",     value: query),
            URLQueryItem(name: "resources", value: "issue"),
            URLQueryItem(name: "limit",     value: "10"),
            URLQueryItem(name: "fieldlist",
                         value: "id,name,issuenumber,description,volume,image")
        ]

        guard let url = components.url else { throw ComicVineError.decodingError }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            throw ComicVineError.networkError(error)
        }

        return try parseIssues(data: data)
    }

    // MARK: - Cover

    func fetchCoverData(from url: URL) async -> Data? {
        try? await session.data(from: url).0
    }

    // MARK: - Parsing Volumes

    private func parseVolumes(data: Data) throws -> [ComicVineResult] {
        guard
            let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let status = json["statuscode"] as? Int
        else { throw ComicVineError.decodingError }

        if status != 1 {
            let error = json["error"] as? String ?? "Errore sconosciuto"
            throw ComicVineError.apiError(error)
        }

        guard let results = json["results"] as? [[String: Any]] else {
            throw ComicVineError.noResults
        }
        if results.isEmpty { throw ComicVineError.noResults }

        return results.compactMap { item -> ComicVineResult? in
            guard
                let id   = item["id"]   as? Int,
                let name = item["name"] as? String
            else { return nil }

            let description = stripHTML(item["description"] as? String ?? "")
            let startYear   = item["startyear"]     as? String
            let issueCount  = item["countofissues"] as? Int

            var publisher = ""
            if let pub = item["publisher"] as? [String: Any] {
                publisher = pub["name"] as? String ?? ""
            }

            var coverURL: URL? = nil
            if let image = item["image"] as? [String: Any] {
                let urlString = image["mediumurl"] as? String
                             ?? image["smallurl"]  as? String
                if let s = urlString { coverURL = URL(string: s) }
            }

            return ComicVineResult(
                id:          id,
                name:        name,
                issueNumber: nil,
                description: description,
                publisher:   publisher,
                startYear:   startYear,
                coverURL:    coverURL,
                issueCount:  issueCount
            )
        }
    }

    // MARK: - Parsing Issues

    private func parseIssues(data: Data) throws -> [ComicVineResult] {
        guard
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let results = json["results"] as? [[String: Any]]
        else { throw ComicVineError.decodingError }

        if results.isEmpty { throw ComicVineError.noResults }

        return results.compactMap { item -> ComicVineResult? in
            guard let id = item["id"] as? Int else { return nil }

            let name        = item["name"]        as? String ?? "Senza titolo"
            let issueNumber = item["issuenumber"] as? String
            let description = stripHTML(item["description"] as? String ?? "")

            var volumeName = ""
            if let vol = item["volume"] as? [String: Any] {
                volumeName = vol["name"] as? String ?? ""
            }

            var coverURL: URL? = nil
            if let image = item["image"] as? [String: Any],
               let s = image["mediumurl"] as? String {
                coverURL = URL(string: s)
            }

            let displayName = volumeName.isEmpty
                ? name
                : "\(volumeName) #\(issueNumber ?? "")"

            return ComicVineResult(
                id:          id,
                name:        displayName,
                issueNumber: issueNumber,
                description: description,
                publisher:   "",
                startYear:   nil,
                coverURL:    coverURL,
                issueCount:  nil
            )
        }
    }

    // MARK: - HTML stripping

    private func stripHTML(_ html: String) -> String {
        guard !html.isEmpty, html.contains("<") else { return html }
        var result = html
        let replacements: [(String, String)] = [
            ("<br>", "\n"), ("<br/>", "\n"), ("</p>", "\n"), ("</li>", "\n")
        ]
        for (tag, replacement) in replacements {
            result = result.replacingOccurrences(of: tag, with: replacement,
                                                  options: .caseInsensitive)
        }
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>",
                                                 options: .caseInsensitive) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range,
                                                     withTemplate: "")
        }
        let htmlEntities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " ")
        ]
        for (entity, char) in htmlEntities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        result = result.components(separatedBy: .whitespacesAndNewlines)
                       .filter { !$0.isEmpty }
                       .joined(separator: " ")
        return result.count > 300 ? String(result.prefix(300)) + "…" : result
    }
}
