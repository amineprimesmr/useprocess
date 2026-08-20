import Foundation

/// Langue produit partagée app + widgets — lit `process.app.language` (même clé que `ProcessAppLanguage`).
nonisolated enum ProcessSharedLanguage {
    static let storageKey = "process.app.language"
    private static let legacyUserDefaultsKey = "selectedLanguage"

    nonisolated static var currentCode: ProcessLanguageCode {
        if let stored = UserDefaults.standard.string(forKey: storageKey) {
            return ProcessLanguageCode.normalize(stored)
        }
        if let legacy = UserDefaults.standard.string(forKey: legacyUserDefaultsKey) {
            return ProcessLanguageCode.normalize(legacy)
        }
        return ProcessLanguageCode.resolveFromDevice()
    }

    nonisolated static var prefersEnglish: Bool {
        currentCode == .english
    }

    nonisolated static var usesFrenchCopy: Bool {
        currentCode == .french
    }

    nonisolated static func t(_ fr: String, en: String) -> String {
        ProcessCopyCatalog.resolve(fr: fr, en: en, code: currentCode)
    }

    nonisolated static func persist(_ code: ProcessLanguageCode) {
        UserDefaults.standard.set(code.rawValue, forKey: storageKey)
        UserDefaults.standard.set(code.rawValue, forKey: legacyUserDefaultsKey)
    }
}
