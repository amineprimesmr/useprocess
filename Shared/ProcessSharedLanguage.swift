import Foundation

/// Langue produit partagée app + widgets — lit `process.app.language` (même clé que `ProcessAppLanguage`).
enum ProcessSharedLanguage {
    static let storageKey = "process.app.language"
    private static let legacyUserDefaultsKey = "selectedLanguage"

    static var currentCode: ProcessLanguageCode {
        if let stored = UserDefaults.standard.string(forKey: storageKey) {
            return ProcessLanguageCode.normalize(stored)
        }
        if let legacy = UserDefaults.standard.string(forKey: legacyUserDefaultsKey) {
            return ProcessLanguageCode.normalize(legacy)
        }
        return ProcessLanguageCode.resolveFromDevice()
    }

    static var prefersEnglish: Bool {
        currentCode == .english
    }

    static var usesFrenchCopy: Bool {
        currentCode == .french
    }

    static func t(_ fr: String, en: String) -> String {
        ProcessCopyCatalog.resolve(fr: fr, en: en, code: currentCode)
    }

    static func persist(_ code: ProcessLanguageCode) {
        UserDefaults.standard.set(code.rawValue, forKey: storageKey)
        UserDefaults.standard.set(code.rawValue, forKey: legacyUserDefaultsKey)
    }
}
