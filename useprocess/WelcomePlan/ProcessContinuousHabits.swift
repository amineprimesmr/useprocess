import Foundation

/// Habitudes 24/7 — guide debloat et coach (hors routine matinale).
enum ProcessContinuousHabits {

    @MainActor static var mewingTitle: String { AppCopy.t("Mewing 24/24", en: "Mewing 24/7") }
    @MainActor static var mewingDetail: String {
        AppCopy.t(
            """
            Langue en vide sur le palais : « T », sourire + yeux ouverts, déglutitions jusqu'à salive épuisée.             Bouche fermée au repos, air par le nez jour et nuit. Semaine 1 : rappel toutes les heures.
            """,
            en: """
            Tongue suctioned to the palate: "T", smile + eyes open, swallow until saliva is gone.             Mouth closed at rest, breathe through the nose day and night. Week 1: hourly reminders.
            """
        )
    }

    @MainActor static var masticationTitle: String { AppCopy.t("Mastication lente", en: "Slow chewing") }
    @MainActor static var masticationDetail: String {
        AppCopy.t(
            "\(ProcessDailyTargets.chewsPerBite) mâchées par bouchée — mastication lente à chaque repas.",
            en: "\(ProcessDailyTargets.chewsPerBite) chews per bite — chew slowly at every meal."
        )
    }

    @MainActor static var postureTitle: String { AppCopy.t("Posture droite", en: "Upright posture") }
    @MainActor static var postureDetail: String { PostureIntelligenceGuide.neckAlignmentDetail }

    @MainActor static var sideSleepTitle: String { AppCopy.t("Respiration nasale", en: "Nasal breathing") }
    @MainActor static var sideSleepDetail: String {
        AppCopy.t(
            "Dormir sur le côté — coussin entre les genoux ; éviter le dos (langue et visage reculent).",
            en: "Sleep on your side — pillow between your knees; avoid your back (tongue and face slide back)."
        )
    }

    @MainActor
    static var all: [(title: String, detail: String)] {
        [
            (mewingTitle, mewingDetail),
            (postureTitle, postureDetail),
            (sideSleepTitle, sideSleepDetail)
        ]
    }
}
