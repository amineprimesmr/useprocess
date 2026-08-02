import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

enum FirebaseBootstrap {
    private static let lock = NSLock()
    private static var didConfigure = false

    /// Configure Firebase de façon idempotente.
    /// Appelé au premier besoin (Auth / AppSession), pas obligatoirement dans `App.init`.
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
}
