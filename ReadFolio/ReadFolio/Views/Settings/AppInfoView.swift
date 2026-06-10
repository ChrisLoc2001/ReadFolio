import SwiftUI

/// Informazioni sull'app: versione, build e servizi di terze parti usati.
struct AppInfoView: View {
    var body: some View {
        Form {
            Section("Versione") {
                LabeledContent("Versione", value: appVersion)
                LabeledContent("Build",    value: buildNumber)
            }

            Section("Fonti dati") {
                LabeledContent("Libri",    value: "Google Books API")
                LabeledContent("Manga",    value: "MangaDex API")
                LabeledContent("Fumetti",  value: "Comic Vine API")
                LabeledContent("Database", value: "Firebase Firestore")
            }
        }
        .navigationTitle("Info")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
