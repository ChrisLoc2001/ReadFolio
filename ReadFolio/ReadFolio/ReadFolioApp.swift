import SwiftUI
import SwiftData

@main
struct ReadfolioApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([ReadingItem.self, Tag.self])
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            #if DEBUG
            print("ModelContainer error: \(error)")
            #endif
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = (try? ModelContainer(for: schema, configurations: [fallback]))
                ?? { fatalError("ModelContainer irrecuperabile: \(error)") }()
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
