import Foundation

enum ProcessHydrationCopy {
    static var goLabel: String { "GO" }

    static var drinkReminderLine: String {
        ProcessSharedLanguage.t("C'est l'heure de t'hydrater", en: "Time to hydrate")
    }

    static var hydrationTitle: String {
        ProcessSharedLanguage.t("Hydratation", en: "Hydration")
    }

    static var nextSipTitle: String {
        ProcessSharedLanguage.t("Prochain sip", en: "Next sip")
    }

    static var drinkNotificationTitle: String {
        ProcessSharedLanguage.t("C'est l'heure de boire", en: "Time to drink")
    }

    static func drinkNotificationBody(isFirst: Bool, hydrationLabel: String) -> String {
        if isFirst {
            return ProcessSharedLanguage.t(
                "Petite gorgée — objectif \(hydrationLabel).",
                en: "Take a sip — \(hydrationLabel) goal."
            )
        }
        return ProcessSharedLanguage.t(
            "Hydratation régulière = moins de gonflement.",
            en: "Steady hydration = less puffy face."
        )
    }
}
