import Foundation

/// Politique de session coach — brouillon vierge au lancement froid, sans entrée dans l’historique tant qu’il n’y a pas de message utilisateur.
enum CoachAppLaunchSession {
    private static var didStartFreshConversationThisProcess = false

    /// `true` une seule fois par processus (kill multitâche → relance = nouveau processus).
    static func consumeColdLaunchFreshConversation() -> Bool {
        guard !didStartFreshConversationThisProcess else { return false }
        didStartFreshConversationThisProcess = true
        return true
    }
}
