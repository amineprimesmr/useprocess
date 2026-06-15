import Foundation

/// Actions rapides du chat — prompts structurés pour Claude.
enum CoachTool: String, CaseIterable, Identifiable, Sendable {
    case explainReadiness
    case analyzeWeek
    case compareScans
    case nutritionAdvice
    case lastScanSummary
    case programRecap

    var id: String { rawValue }

    var label: String {
        switch self {
        case .explainReadiness: return "Readiness"
        case .analyzeWeek: return "Ma semaine"
        case .compareScans: return "Comparer scans"
        case .nutritionAdvice: return "Nutrition"
        case .lastScanSummary: return "Dernier scan"
        case .programRecap: return "Mon plan"
        }
    }

    var icon: String {
        switch self {
        case .explainReadiness: return "bolt.heart.fill"
        case .analyzeWeek: return "calendar"
        case .compareScans: return "arrow.left.arrow.right"
        case .nutritionAdvice: return "fork.knife"
        case .lastScanSummary: return "viewfinder"
        case .programRecap: return "list.bullet.rectangle"
        }
    }

    func buildPrompt(context: CoachUserContext) -> String {
        switch self {
        case .explainReadiness:
            return """
            Explique mon score readiness actuel (\(context.health?.readinessScore.map(String.init) ?? "—")/100) \
            en 5-7 phrases : cause biologique probable, impact sur la journée, 2 actions concrètes aujourd'hui.
            """
        case .analyzeWeek:
            return """
            Analyse ma semaine santé avec les données disponibles dans le CONTEXTE UTILISATEUR.
            Tendances sommeil / effort / récupération. 3 insights + 3 priorités pour les 7 prochains jours.
            """
        case .compareScans:
            let count = BodyScanHistoryStore.shared.history.count
            return """
            Compare mes \(count) scans corporels enregistrés (historique local).
            Évolution posture, asymétries, priorités musculaires. Progrès ou régressions + plan correctif.
            """
        case .nutritionAdvice:
            return """
            Donne un plan nutrition Protocole Origine personnalisé (6-8 phrases) basé sur mon profil \
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
            3 piliers Protocole Origine prioritaires, habitudes quotidiennes.
            """
        }
    }
}
