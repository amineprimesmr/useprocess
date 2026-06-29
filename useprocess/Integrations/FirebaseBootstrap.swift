import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

enum FirebaseBootstrap {
    private static var didConfigure = false

    /// L'initialisation d'une propriété statique Swift est atomique et ne
    /// s'exécute qu'une seule fois, même si plusieurs services appellent
    /// `configure()` au lancement.
    private static let configureOnce: Void = {
        guard AppConfiguration.firebaseConfigured else { return }

        FirebaseAppAttestation.installProviderFactory()
        FirebaseApp.configure()

        let settings = Firestore.firestore().settings
        settings.cacheSettings = PersistentCacheSettings(
            sizeBytes: NSNumber(value: 100 * 1024 * 1024)
        )
        Firestore.firestore().settings = settings
        didConfigure = true
    }()

    static func configure() {
        _ = configureOnce
    }

    static var isConfigured: Bool {
        configure()
        return didConfigure
    }
}
