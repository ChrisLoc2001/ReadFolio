import Foundation

enum Constants {
    enum App {
        static let name    = "Readfolio"
        static let version = "1.0.0"
    }

    enum Storage {
        static let maxCoverDimension: CGFloat = 600
        static let jpegQuality: CGFloat       = 0.8
    }

    enum GoogleBooks {
        static let baseURL    = "https://www.googleapis.com/books/v1"
        static let maxResults = 20
    }

    enum MangaDex {
        static let baseURL   = "https://api.mangadex.org"
        static let coversURL = "https://uploads.mangadex.org/covers"
        static let maxResults = 20
    }

    enum ComicVine {
        static let baseURL    = "https://comicvine.gamespot.com/api"
        static let maxResults = 20
    }

    // Chiavi persistite in UserDefaults tramite @AppStorage in SettingsView.
    // Non hardcodate qui — l'utente le inserisce nelle Impostazioni.
    enum UserDefaultsKeys {
        static let googleBooksAPIKey = "googleBooksAPIKey"
        static let comicVineAPIKey   = "comicVineAPIKey"
    }
}
