import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

enum FirebaseBootstrap {
    /// Recursive : `FirebaseApp.configure()` peut rappeler du code app qui re-entre ici.
    private static let lock = NSRecursiveLock()
    private static var didConfigure = false

    /// Configure Firebase de façon idempotente.
    /// Doit être appelé dès `App.init` — avant tout accès Auth / AppSession / onboarding.
    static func configure() {
        lock.lock()
        defer { lock.unlock() }

        guard !didConfigure else { return }
        guard AppConfiguration.firebaseConfigured else { return }

        if FirebaseApp.app() != nil {
            didConfigure = true
            return
        }

        FirebaseAppAttestation.installProviderFactory()
        FirebaseApp.configure()

        // Cache modéré — appliqué immédiatement avant tout accès Firestore.
        let settings = Firestore.firestore().settings
        settings.cacheSettings = PersistentCacheSettings(
            sizeBytes: NSNumber(value: 50 * 1024 * 1024)
        )
        Firestore.firestore().settings = settings

        didConfigure = FirebaseApp.app() != nil
    }

    static var isConfigured: Bool {
        configure()
        lock.lock()
        defer { lock.unlock() }
        return didConfigure
    }

    /// `true` seulement si le default app existe déjà (sans forcer configure).
    static var isAppReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didConfigure || FirebaseApp.app() != nil
    }
}
