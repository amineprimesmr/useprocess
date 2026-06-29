import FirebaseAppCheck
import FirebaseCore
import Foundation

private final class ProcessAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        }
        return DeviceCheckProvider(app: app)
    }
}

enum FirebaseAppAttestation {
    private static let providerFactory = ProcessAppCheckProviderFactory()
    private static var isInstalled = false

    /// Doit impérativement être appelé avant `FirebaseApp.configure()`.
    static func installProviderFactory() {
        guard !isInstalled else { return }
        AppCheck.setAppCheckProviderFactory(providerFactory)
        isInstalled = true
    }

    static func token(forcingRefresh: Bool = false) async throws -> String {
        let result = try await AppCheck.appCheck().token(forcingRefresh: forcingRefresh)
        return result.token
    }
}
