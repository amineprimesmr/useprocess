import Foundation
import FirebaseAuth
import FirebaseAuth

/// Clés UserDefaults / cache isolées par utilisateur Firebase.
enum UserScopedStorage {
    private static let prefix = AppConfiguration.bundleIdentifier + ".users"

    static func currentUserId() -> String? {
        Auth.auth().currentUser?.uid
    }

    static func key(_ base: String, userId: String? = currentUserId()) -> String {
        let uid = userId ?? "anonymous"
        return "\(prefix).\(uid).\(base)"
    }

    static func globalKey(_ base: String) -> String {
        "\(AppConfiguration.bundleIdentifier).\(base)"
    }
}
