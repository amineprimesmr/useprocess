import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

enum FirebaseBootstrap {
    static func configure() {
        guard AppConfiguration.firebaseConfigured else { return }
        guard FirebaseApp.app() == nil else { return }

        FirebaseApp.configure()

        let settings = Firestore.firestore().settings
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        Firestore.firestore().settings = settings

        AppIntegrations.shared.refresh()
    }
}
