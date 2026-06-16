import Foundation

/// Clés UserDefaults / cache isolées par utilisateur Firebase.
enum UserScopedStorage {
    private static let prefix = AppConfiguration.bundleIdentifier + ".users"

    /// Bases connues effacées lors d'une suppression de compte.
    static let userDataKeys: [String] = [
        "onboarding.completed",
        "welcome.plan.chat.completed",
        "welcome.questionnaire",
        "welcome.plan",
        "unified.profile",
        "socialProfile",
        "coach.thread",
        "coach.daily_brief",
        "coach.daily_brief_date",
        "coach.global.memory",
        "coach.conversations.library",
        "facescan.latest",
        "facescan.history",
        "bodyscan.latest",
        "bodyscan.history"
    ]

    static func currentUserId() -> String? {
        AuthUser.current?.uid
    }

    static func key(_ base: String, userId: String? = currentUserId()) -> String {
        let uid = userId ?? "anonymous"
        return "\(prefix).\(uid).\(base)"
    }

    static func globalKey(_ base: String) -> String {
        "\(AppConfiguration.bundleIdentifier).\(base)"
    }

    static func likelyUserIds(primary: String) -> [String] {
        var ids = Set([primary, "local-user", "anonymous"])
        if let current = currentUserId() {
            ids.insert(current)
        }
        return Array(ids)
    }

    static func clearAllUserData(userId: String) {
        for base in userDataKeys {
            UserDefaults.standard.removeObject(forKey: key(base, userId: userId))
        }
    }
}
