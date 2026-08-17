import Foundation
import UserNotifications

/// Support in-app : UI Process native. Crisp n’est plus ouvert dans l’app
/// (il reste l’inbox opérateur via Cloud Functions).
@MainActor
enum ProcessCrispSupport {
    static var isReady: Bool {
        AuthUser.current != nil && ClaudeConfiguration.functionsBaseURL != nil
    }

    static func configure() {}

    static func syncUser() {}

    static func resetSession() {}

    static func setDeviceToken(_ deviceToken: Data) {}

    static func isCrispPushNotification(_ notification: UNNotification) -> Bool {
        false
    }

    static func handlePushNotification(_ notification: UNNotification) {}

    static func registerForRemoteNotificationsIfAllowed() {}
}
