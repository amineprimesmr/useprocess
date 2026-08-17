import Foundation
import Observation

private enum ProcessAppLanguageKeys {
    nonisolated static let storageKey = "process.app.language"
    nonisolated static let legacyUserDefaultsKey = "selectedLanguage"
}

/// Langue produit de l’app — pilotée par le device au premier lancement, puis par le sélecteur onboarding.
@MainActor
@Observable
final class ProcessAppLanguage {
    static let shared = ProcessAppLanguage()

    enum Code: String, CaseIterable, Identifiable, Sendable {
        case french = "fr"
        case english = "en"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .french: return AppCopy.tSync("Français", en: "French")
            case .english: return "English"
            }
        }

        var flag: String {
            switch self {
            case .french: return "🇫🇷"
            case .english: return "🇺🇸"
            }
        }

        nonisolated var localeIdentifier: String {
            switch self {
            case .french: return "fr_FR"
            case .english: return "en_US"
            }
        }
    }

    private(set) var code: Code

    var isEnglish: Bool { code == .english }
    var isFrench: Bool { code == .french }
    var locale: Locale { Locale(identifier: code.localeIdentifier) }

    /// Locale pour formatters hors MainActor (dates, nombres).
    nonisolated static var currentLocale: Locale {
        let code = loadStoredCode() ?? resolveFromDevice()
        return Locale(identifier: code.localeIdentifier)
    }

    /// Langue produit hors MainActor (feedback caméra, parsers).
    nonisolated static var prefersEnglish: Bool {
        (loadStoredCode() ?? resolveFromDevice()) == .english
    }

    private init() {
        if let stored = Self.loadStoredCode() {
            code = stored
        } else {
            code = Self.resolveFromDevice()
            Self.persist(code)
        }
    }

    /// Relit UserDefaults (appelé au lancement pour garantir un état frais).
    func bootstrap() {
        if let stored = Self.loadStoredCode() {
            code = stored
        } else {
            code = Self.resolveFromDevice()
            Self.persist(code)
        }
    }

    func setLanguage(_ newCode: Code) {
        guard newCode != code else { return }
        code = newCode
        Self.persist(newCode)
    }

    func setLanguage(codeString: String) {
        let normalized = Self.normalize(codeString)
        setLanguage(normalized)
    }

    // MARK: - Resolution

    nonisolated static func resolveFromDevice(
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> Code {
        for tag in preferredLanguages {
            let lower = tag.lowercased()
            if lower.hasPrefix("fr") { return .french }
            if lower.hasPrefix("en") { return .english }
        }
        // Non-FR device (US, UK, DE, ES, …) → English for App Store anglophone targeting.
        return .english
    }

    nonisolated static func normalize(_ raw: String) -> Code {
        let lower = raw.lowercased()
        if lower.hasPrefix("fr") { return .french }
        return .english
    }

    // MARK: - Persistence

    nonisolated private static func loadStoredCode() -> Code? {
        if let value = UserDefaults.standard.string(forKey: ProcessAppLanguageKeys.storageKey) {
            return normalize(value)
        }
        if let legacy = UserDefaults.standard.string(forKey: ProcessAppLanguageKeys.legacyUserDefaultsKey) {
            let code = normalize(legacy)
            persist(code)
            return code
        }
        return nil
    }

    nonisolated private static func persist(_ code: Code) {
        UserDefaults.standard.set(code.rawValue, forKey: ProcessAppLanguageKeys.storageKey)
        UserDefaults.standard.set(code.rawValue, forKey: ProcessAppLanguageKeys.legacyUserDefaultsKey)
    }
}
