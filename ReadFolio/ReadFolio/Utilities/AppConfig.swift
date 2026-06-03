import Foundation

/// Unica fonte di verità per le API key di terze parti.
///
/// Le chiavi vivono in `Secrets.xcconfig` (non versionato) → vengono iniettate in
/// `Info.plist` tramite `ReadFolio.xcconfig`. Sia i servizi di rete sia la UI leggono
/// da qui, così l'app ha un solo concetto di "chiave configurata".
// `nonisolated`: AppConfig legge solo da Bundle.main (thread-safe) e deve essere
// raggiungibile sia dalla UI (@MainActor) sia dai servizi `actor`. Senza questo,
// con SWIFT_APPROACHABLE_CONCURRENCY il tipo verrebbe isolato a @MainActor e
// non sarebbe accessibile dall'interno degli actor di rete.
nonisolated enum AppConfig {

    /// Placeholder usato in `Secrets.xcconfig.example`. Una chiave uguale a questo
    /// valore (o vuota) è considerata "non configurata".
    private static let placeholder = "la_tua_key"

    static var googleBooksAPIKey: String { value(for: "GoogleBooksAPIKey") }
    static var comicVineAPIKey:   String { value(for: "ComicVineAPIKey") }

    static var isGoogleBooksConfigured: Bool { isConfigured(googleBooksAPIKey) }
    static var isComicVineConfigured:   Bool { isConfigured(comicVineAPIKey) }

    private static func value(for key: String) -> String {
        (Bundle.main.infoDictionary?[key] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isConfigured(_ value: String) -> Bool {
        !value.isEmpty && value != placeholder
    }
}
