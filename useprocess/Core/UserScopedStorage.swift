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
        "bodyscan.history",
        "subscription.complimentary.access",
        "privacy.ai_third_party",
        "privacy.ai_third_party.date",
        "privacy.face_capture",
        "privacy.face_capture.date",
        "privacy.face_ai",
        "process.streak",
        "process.evening_checkin",
        "process.debloat.trajectory",
        "process.plan.progress",
        "process.activity.status",
        "process.debloat.food_prefs",
        "process.hydration_log",
        "plan.home.layout",
        "plan.home.face_scan.shows_video",
        "referral.program",
        "creator.mode.unlocked",
        "creator.mode.quality",
        "creator.mode.look",
        "coach.my_memory",
        "coach.checkins",
        "coach.process_files",
        "onboarding.face_markers",
        "onboarding.face_mesh",
        "onboarding.face_scan_payload",
        "welcome.plan.progress"
    ]

    /// Sous-clés connues pour les préfixes composés (coach.intelligence.*, coach.daily_rhythm.*).
    private static let prefixedUserDataSuffixes: [String: [String]] = [
        "coach.intelligence": [
            "enabled", "personality", "followUps", "reproductiveHealth",
            "weeklyCount", "extraCredits", "weeklyReset", "subscriberGrantWeek"
        ],
        "coach.my_memory": ["enabled"],
        "coach.checkins": ["enabled"]
    ]

    static func currentUserId() -> String? {
        // Ne force pas Auth tant que Firebase n'est pas prêt (évite le log I-COR000003).
        guard FirebaseBootstrap.isAppReady || AppConfiguration.firebaseConfigured else {
            return nil
        }
        return AuthUser.current?.uid
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

        for (prefix, suffixes) in prefixedUserDataSuffixes {
            let root = key(prefix, userId: userId)
            UserDefaults.standard.removeObject(forKey: root)
            for suffix in suffixes {
                UserDefaults.standard.removeObject(forKey: "\(root).\(suffix)")
            }
        }

        clearDailyRhythmKeys(userId: userId)
    }

    private static func clearDailyRhythmKeys(userId: String) {
        let rhythmPrefix = key("coach.daily_rhythm.", userId: userId)
        let defaults = UserDefaults.standard
        for entry in defaults.dictionaryRepresentation().keys where entry.hasPrefix(rhythmPrefix) {
            defaults.removeObject(forKey: entry)
        }
    }
}
