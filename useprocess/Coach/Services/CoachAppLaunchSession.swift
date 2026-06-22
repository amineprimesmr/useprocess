import Foundation

/// Politique de session coach — une nouvelle conversation à chaque lancement froid (app retirée des récents).
enum CoachAppLaunchSession {
    private static var didStartFreshConversationThisProcess = false

    /// `true` une seule fois par processus (kill multitâche → relance = nouveau processus).
    static func consumeColdLaunchFreshConversation() -> Bool {
        guard !didStartFreshConversationThisProcess else { return false }
        didStartFreshConversationThisProcess = true
        return true
    }
}
