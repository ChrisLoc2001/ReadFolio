import SwiftUI
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import FirebaseAuth

@main
struct ReadfolioApp: App {
    @StateObject private var authVM = AuthViewModel()

    init() {
        FirebaseApp.configure()

        // Abilita cache offline Firestore
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        Firestore.firestore().settings = settings

        // Configura Google Sign-In
        if let clientID = FirebaseApp.app()?.options.clientID {
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authVM)
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(authVM)
        }
        #endif
    }
}

struct RootView: View {
    @EnvironmentObject private var authVM: AuthViewModel

    var body: some View {
        Group {
            if authVM.isCheckingAuth {
                ProgressView("Caricamento…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if authVM.isAuthenticated {
                ContentView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut, value: authVM.isAuthenticated)
    }
}
