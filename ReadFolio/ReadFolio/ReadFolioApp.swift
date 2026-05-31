import SwiftUI
import SwiftData

@main
struct ReadfolioApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([ReadingItem.self, Tag.self])
            // CloudKit sync: sostituisci `ModelConfiguration(schema:)` con
            // `ModelConfiguration(schema:, cloudKitDatabase: .automatic)`
            // dopo aver abilitato iCloud + CloudKit nel progetto Xcode.
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Impossibile creare il ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
