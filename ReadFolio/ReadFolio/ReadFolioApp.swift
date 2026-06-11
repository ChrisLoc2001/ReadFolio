import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAppCheck
import GoogleSignIn
import FirebaseAuth

/// Fornisce il provider App Check usato in produzione: App Attest (iOS 14+),
/// che attesta crittograficamente che le richieste arrivino da una build
/// legittima dell'app su un dispositivo reale.
final class ReadfolioAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}

@main
struct ReadfolioApp: App {
    @StateObject private var authVM = AuthViewModel()

    init() {
        // App Check DEVE essere configurato PRIMA di FirebaseApp.configure().
        // In DEBUG (simulatore/sviluppo) si usa il debug provider, che stampa in
        // console un token da registrare nella console Firebase. In release si usa
        // App Attest. NOTA: questo NON attiva da solo l'enforcement — finché non
        // lo abiliti in console (Firestore/Storage/Auth) App Check resta in
        // monitoraggio e non blocca nessuna richiesta.
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(ReadfolioAppCheckProviderFactory())
        #endif

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
                if authVM.needsProfileSetup {
                    ProfileSetupView()
                } else {
                    ContentView()
                }
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut, value: authVM.isAuthenticated)
        .animation(.easeInOut, value: authVM.needsProfileSetup)
    }
}
