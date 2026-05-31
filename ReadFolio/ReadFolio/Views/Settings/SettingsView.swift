import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context

    // API Keys persistite in UserDefaults
    @AppStorage("googleBooksAPIKey") private var googleBooksKey = ""
    @AppStorage("comicVineAPIKey")   private var comicVineKey   = ""

    @State private var showingImportPicker = false
    @State private var feedbackMessage: String? = nil
    @State private var showingFeedback = false
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - API Keys
                Section {
                    apiKeyRow(
                        label: "Google Books",
                        placeholder: "Facoltativa — 1000 req/giorno con key",
                        key: $googleBooksKey,
                        infoURL: "https://developers.google.com/books"
                    )
                    apiKeyRow(
                        label: "Comic Vine",
                        placeholder: "Obbligatoria per i fumetti",
                        key: $comicVineKey,
                        infoURL: "https://comicvine.gamespot.com/api"
                    )
                } header: {
                    Text("API Keys")
                } footer: {
                    Text("MangaDex non richiede alcuna key. Le chiavi vengono salvate solo su questo dispositivo.")
                }

                // MARK: - Dati
                Section("Dati") {
                    Button {
                        isExporting = true
                        exportData()
                        isExporting = false
                    } label: {
                        Label("Esporta in JSON", systemImage: "arrow.up.doc")
                    }
                    .disabled(isExporting)
                    .keyboardShortcut("e", modifiers: [.command, .shift])

                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Importa da JSON", systemImage: "arrow.down.doc")
                    }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                }

                // MARK: - Info
                Section("Info") {
                    LabeledContent("Versione", value: appVersion)
                    LabeledContent("Build",    value: buildNumber)
                    LabeledContent("Persistenza", value: "SwiftData")
                    LabeledContent("Libri",    value: "Google Books API")
                    LabeledContent("Manga",    value: "MangaDex API")
                    LabeledContent("Fumetti",  value: "Comic Vine API")
                }
            }
            .navigationTitle("Impostazioni")
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                importData(result: result)
            }
            .alert("Operazione completata", isPresented: $showingFeedback) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(feedbackMessage ?? "")
            }
        }
    }

    // MARK: - API Key Row

    private func apiKeyRow(
        label: String,
        placeholder: String,
        key: Binding<String>,
        infoURL: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Link("Ottieni key", destination: URL(string: infoURL)!)
                    .font(.caption)
            }
            SecureField(placeholder, text: key)
                .font(.caption)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Export

    private func exportData() {
        do {
            let repo  = ItemRepository(context: context)
            let items = try repo.fetchAll()
            let data  = try ExportImportService.exportJSON(items: items)

            let filename = "readfolio_export_\(Date().ISO8601Format()).json"
            let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent(filename)
            try data.write(to: url)

            feedbackMessage = "Esportati \(items.count) elementi.\nFile: \(url.lastPathComponent)"
        } catch {
            feedbackMessage = "Errore durante l'esportazione: \(error.localizedDescription)"
        }
        showingFeedback = true
    }

    // MARK: - Import

    private func importData(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                feedbackMessage = "Impossibile accedere al file."
                showingFeedback = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data  = try Data(contentsOf: url)
                let count = try ExportImportService.importJSON(data: data, context: context)
                feedbackMessage = "Importati \(count) elementi con successo."
            } catch {
                feedbackMessage = "Errore durante l'importazione: \(error.localizedDescription)"
            }

        case .failure(let error):
            feedbackMessage = "Impossibile aprire il file: \(error.localizedDescription)"
        }
        showingFeedback = true
    }

    // MARK: - App info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
