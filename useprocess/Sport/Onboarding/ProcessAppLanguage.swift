import Foundation
import Observation

/// Langue produit de l’app — pilotée par le device au premier lancement, puis par le sélecteur onboarding.
@MainActor
@Observable
final class ProcessAppLanguage {
    static let shared = ProcessAppLanguage()

    typealias Code = ProcessLanguageCode

    private(set) var code: Code

    var isEnglish: Bool { code == .english }
    var isFrench: Bool { code == .french }
    var locale: Locale { Locale(identifier: code.localeIdentifier) }

    /// Locale pour formatters hors MainActor (dates, nombres).
    nonisolated static var currentLocale: Locale {
        Locale(identifier: currentCode.localeIdentifier)
    }

    nonisolated static var currentCode: Code {
        ProcessSharedLanguage.currentCode
    }

    /// `true` seulement si la langue produit est l’anglais US.
    nonisolated static var prefersEnglish: Bool {
        currentCode == .english
    }

    /// `true` seulement si la langue produit est le français — prompts / légal / EUR.
    nonisolated static var usesFrenchCopy: Bool {
        currentCode == .french
    }

    private init() {
        if let stored = UserDefaults.standard.string(forKey: ProcessSharedLanguage.storageKey) {
            code = Code.normalize(stored)
        } else {
            code = Code.resolveFromDevice()
            ProcessSharedLanguage.persist(code)
        }
    }

    /// Relit UserDefaults (appelé au lancement pour garantir un état frais).
    func bootstrap() {
        code = ProcessSharedLanguage.currentCode
        ProcessSharedLanguage.persist(code)
    }

    func setLanguage(_ newCode: Code) {
        guard newCode != code else { return }
        code = newCode
        ProcessSharedLanguage.persist(newCode)
    }

    func setLanguage(codeString: String) {
        setLanguage(Code.normalize(codeString))
    }

    nonisolated static func resolveFromDevice(
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> Code {
        Code.resolveFromDevice(preferredLanguages: preferredLanguages)
    }

    nonisolated static func normalize(_ raw: String) -> Code {
        Code.normalize(raw)
    }
}
