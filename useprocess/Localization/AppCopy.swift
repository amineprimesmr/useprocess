import Foundation

/// Textes produit — FR / EN dans le call site, autres langues via `ProcessCopyCatalog`.
/// `OnboardingCopy` reste un alias de compatibilité.
///
/// Explicitement non-isolé : avec `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
/// un `enum` hériterait sinon du MainActor et casserait `LocalizedError` / services.
nonisolated enum AppCopy {
    @MainActor
    static var isEnglish: Bool { ProcessAppLanguage.shared.isEnglish }

    /// Libellé produit selon la langue app (branding Process appliqué).
    static func t(_ fr: String, en: String) -> String {
        tSync(fr, en: en)
    }

    /// Alias explicite pour contextes nonisolés (HUD caméra, quality feedback).
    static func tSync(_ fr: String, en: String) -> String {
        let value = ProcessCopyCatalog.resolve(
            fr: fr,
            en: en,
            code: ProcessSharedLanguage.currentCode
        )
        return AppBranding.replacingProcess(in: value)
    }

    @MainActor
    static func titleLines(from lines: [String]) -> [String] {
        lines.map { AppBranding.replacingProcess(in: $0) }
    }

    @MainActor
    static func text(_ value: String, blank english: String = "") -> String {
        if !english.isEmpty {
            return tSync(value, en: english)
        }
        return AppBranding.replacingProcess(in: value)
    }

    @MainActor
    static func choiceLabel(index: Int, sport: String) -> String {
        sport
    }

    @MainActor
    static func binaryLabels(sportFirst: String, sportSecond: String) -> (String, String) {
        (sportFirst, sportSecond)
    }

    @MainActor
    static func binaryLabels(
        frFirst: String, frSecond: String,
        enFirst: String, enSecond: String
    ) -> (String, String) {
        return (
            tSync(frFirst, en: enFirst),
            tSync(frSecond, en: enSecond)
        )
    }

    @MainActor
    static func placeholder(_ value: String) -> String {
        value
    }

    // MARK: - Shared CTAs (nonisolated — safe in default args / HUD)

    nonisolated static var continueCTA: String { tSync("Continuer", en: "Continue") }
    nonisolated static var continueCTAUpper: String { tSync("CONTINUER", en: "CONTINUE") }
    nonisolated static var cancel: String { tSync("Annuler", en: "Cancel") }
    nonisolated static var save: String { tSync("Enregistrer", en: "Save") }
    nonisolated static var close: String { tSync("Fermer", en: "Close") }
    nonisolated static var done: String { tSync("Terminé", en: "Done") }
    nonisolated static var today: String { tSync("Aujourd'hui", en: "Today") }
    nonisolated static var yes: String { tSync("Oui", en: "Yes") }
    nonisolated static var no: String { tSync("Non", en: "No") }
    nonisolated static var retry: String { tSync("Réessayer", en: "Try again") }
    nonisolated static var delete: String { tSync("Supprimer", en: "Delete") }
    nonisolated static var back: String { tSync("Retour", en: "Back") }
    nonisolated static var next: String { tSync("Suivant", en: "Next") }
    nonisolated static var validate: String { tSync("Valider", en: "Confirm") }
    nonisolated static var send: String { tSync("Envoyer", en: "Send") }
    nonisolated static var search: String { tSync("Rechercher", en: "Search") }
    nonisolated static var settings: String { tSync("Réglages", en: "Settings") }
    nonisolated static var profile: String { tSync("Profil", en: "Profile") }
    nonisolated static var home: String { tSync("Accueil", en: "Home") }
    nonisolated static var meals: String { tSync("Repas", en: "Meals") }
}

/// Alias — l’onboarding et le reste de l’app partagent la même API.
typealias OnboardingCopy = AppCopy
