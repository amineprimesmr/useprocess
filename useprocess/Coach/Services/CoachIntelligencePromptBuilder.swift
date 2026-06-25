import Foundation

/// Construit le system prompt Process Intelligence (personnalité, mémoire, WHOOP/Bevel patterns).
@MainActor
enum CoachIntelligencePromptBuilder {

    static func intelligenceBlock(isModify: Bool, isMeal: Bool) -> String {
        guard CoachIntelligenceSettingsStore.shared.isEnabled else { return "" }

        var parts: [String] = ["\nPROCESS INTELLIGENCE — ACTIF"]
        parts.append(personalityBlock())
        parts.append(whoopBehaviorBlock(isModify: isModify, isMeal: isMeal))

        if CoachIntelligenceSettingsStore.shared.showsExtendedReasoning, !isModify, !isMeal {
            parts.append(extendedReasoningBlock())
        }
        if CoachIntelligenceSettingsStore.shared.showsSuggestedFollowUps, !isModify, !isMeal {
            parts.append(followUpBlock())
        }

        parts.append(deepLinkBlock())
        parts.append(memoryUpdateBlock())
        parts.append(artifactBlock())
        if !isModify {
            parts.append(foodLogBlock())
        }
        parts.append(CoachTrainingTemplateStore.promptBlock(plan: WelcomePlanStore.shared.plan))
        parts.append(CoachMyMemoryStore.shared.promptBlock())
        parts.append(CoachProcessFilesStore.shared.promptBlock())

        return parts.joined(separator: "\n")
    }

    private static func personalityBlock() -> String {
        switch CoachIntelligenceSettingsStore.shared.personality {
        case .dataNerd:
            return """
            PERSONNALITÉ — Nerd des données :
            - Analytique, cite les chiffres du contexte (readiness, HRV, pas, score protocole).
            - Explique le « pourquoi » en 1 phrase max.
            """
        case .directCoach:
            return """
            PERSONNALITÉ — Coach direct (Commander) :
            - Très concis, impératif bienveillant, zéro fluff.
            - Dis clairement quoi faire maintenant et pourquoi c'est la priorité.
            """
        case .warmGuide:
            return """
            PERSONNALITÉ — Guide bienveillant (Friend) :
            - Ton chaleureux, encourage la régularité sans culpabiliser.
            - Valide l'effort avant de conseiller la suite.
            """
        case .guardian:
            return """
            PERSONNALITÉ — Guardian :
            - Calme, long terme, protège la santé avant la performance.
            - Si readiness basse ou fatigue scan → priorise récupération.
            """
        }
    }

    private static func whoopBehaviorBlock(isModify: Bool, isMeal: Bool) -> String {
        if isModify || isMeal { return "" }
        return """
        COMPORTEMENT WHOOP/BEVEL :
        - Explain → Personalize : si question éducative, 1 phrase générale puis 1 phrase avec SES données.
        - Ne jamais inventer une métrique absente du contexte.
        - Toujours 1 action exécutable aujourd'hui dans l'app (journal, repas, scan, séance protocole).
        - Réponse visible : 2–4 phrases max. Pas de markdown.
        - Cite au moins 1 data réelle quand disponible (readiness, sommeil, jour protocole, scan visage).
        - Si l'utilisateur mentionne un repas consommé, propose de l'enregistrer dans le journal nutrition (DEEP_LINK: journal).
        - Pour une séance protocole, rappelle le template du jour (nom, durée) si présent dans le contexte.
        """
    }

    private static func extendedReasoningBlock() -> String {
        """
        ÉTAPES DE RÉFLEXION (obligatoire en fin de réponse, bloc séparé) :
        REASONING: [2–3 phrases courtes — comment tu as utilisé le contexte pour conclure]
        """
    }

    private static func followUpBlock() -> String {
        """
        SUIVIS SUGGÉRÉS (obligatoire en fin de réponse, bloc séparé) :
        FOLLOW_UP_1: [question courte contextualisée]
        FOLLOW_UP_2: [question courte optionnelle]
        """
    }

    private static func deepLinkBlock() -> String {
        """
        LIEN APP (1 seul, fin de réponse) :
        DEEP_LINK: [plan|journal|scan|streak|integration]|[libellé bouton court]
        Exemples : DEEP_LINK: plan|Voir mon journal · DEEP_LINK: scan|Faire mon scan
        """
    }

    private static func memoryUpdateBlock() -> String {
        """
        MÉMOIRE AUTO (si info perso nouvelle et utile, max 1 ligne) :
        MEMORY_UPDATE: [goals|identity|lifestyle|preferences|events|healthHistory|mood]|[texte court]
        """
    }

    private static func artifactBlock() -> String {
        """
        ARTEFACT DATA (optionnel, si tu résumes une tendance chiffrée) :
        ARTIFACT: [titre court]|[2-3 phrases avec chiffres du contexte]
        """
    }

    private static func foodLogBlock() -> String {
        """
        REPAS NOTÉ (si l'utilisateur dit ce qu'il a mangé) :
        FOOD_LOG: ou format MEAL_NAME: … complet pour enregistrement journal.
        """
    }
}
