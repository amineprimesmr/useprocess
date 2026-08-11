import Foundation

/// Langue produit partagée app + widgets — lit `process.app.language` (même clé que `ProcessAppLanguage`).
enum ProcessSharedLanguage {
    private static let storageKey = "process.app.language"

    static var prefersEnglish: Bool {
        if let stored = UserDefaults.standard.string(forKey: storageKey) {
            return !stored.lowercased().hasPrefix("fr")
        }
        for tag in Locale.preferredLanguages {
            let lower = tag.lowercased()
            if lower.hasPrefix("fr") { return false }
            if lower.hasPrefix("en") { return true }
        }
        return true
    }

    static func t(_ fr: String, en: String) -> String {
        prefersEnglish ? en : fr
    }
}
