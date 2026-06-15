import Foundation

@MainActor
@Observable
final class AppIntegrations {
    static let shared = AppIntegrations()

    private(set) var firebaseReady = false
    private(set) var authReady = false

    private init() {}

    func refresh() {
        firebaseReady = AppConfiguration.firebaseConfigured
        authReady = firebaseReady && AuthUser.current != nil
    }

    var summary: String {
        if !firebaseReady { return "Firebase non configuré" }
        return authReady ? "Firebase · Auth connectée" : "Firebase · Auth en attente"
    }
}
