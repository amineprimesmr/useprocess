import Foundation

/// Actions rapides du chat — prompts structurés pour Claude.
enum CoachTool: String, CaseIterable, Identifiable, Sendable {
    case analyzeWeek
    case compareScans
    case nutritionAdvice
    case lastScanSummary
    case programRecap

    var id: String { rawValue }

    var label: String {
        switch self {
        case .analyzeWeek: return AppCopy.t("Ma semaine", en: "My week")
        case .compareScans: return AppCopy.t("Comparer scans", en: "Compare scans")
        case .nutritionAdvice: return AppCopy.t("Nutrition", en: "Nutrition")
        case .lastScanSummary: return AppCopy.t("Dernier scan", en: "Latest scan")
        case .programRecap: return AppCopy.t("Mon plan", en: "My plan")
        }
    }

    var icon: String {
        switch self {
        case .analyzeWeek: return "calendar"
        case .compareScans: return "arrow.left.arrow.right"
        case .nutritionAdvice: return "fork.knife"
        case .lastScanSummary: return "viewfinder"
        case .programRecap: return "list.bullet.rectangle"
        }
    }

    func buildPrompt(context: CoachUserContext) -> String {
        switch self {
        case .analyzeWeek:
            return """
            Analyse ma semaine santé avec les données disponibles dans le CONTEXTE UTILISATEUR.
            Tendances sommeil / effort / récupération. 3 insights + 3 priorités pour les 7 prochains jours.
            N’utilise jamais le mot readiness.
            """
        case .compareScans:
            let count = BodyScanHistoryStore.shared.history.count
            return """
            Compare mes \(count) scans corporels enregistrés (historique local).
            Évolution posture, asymétries, priorités musculaires. Progrès ou régressions + plan correctif.
            """
        case .nutritionAdvice:
            return """
            Donne un plan nutrition personnalisé (6-8 phrases) basé sur mon profil \
            et ma qualité alimentation déclarée (\(context.profile?.nutritionQuality ?? "—")).
            """
        case .lastScanSummary:
            return """
            Résume mon dernier scan corporel en langage simple (score \(context.lastBodyScan?.postureScore.map(String.init) ?? "—")/100) \
            et donne 3 exercices/habitudes prioritaires cette semaine.
            """
        case .programRecap:
            return """
            Rappelle mon plan useprocess 13 semaines basé sur mon profil onboarding : objectif, rythme, \
            3 piliers du plan personnalisé prioritaires, habitudes quotidiennes.
            """
        }
    }
}
