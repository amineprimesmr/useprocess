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
        parts.append(contextualActionsBlock(isModify: isModify, isMeal: isMeal))
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
        - Pose tes questions à l'utilisateur DANS le texte de réponse visible, pas dans FOLLOW_UP.
        - FOLLOW_UP = seulement ce que l'utilisateur pourrait te demander ensuite (ex: "Autre idée de dîner").
        - Préfère ACTION_* (boutons app) plutôt que FOLLOW_UP quand une action concrète existe.
        - Si tu proposes une séance, liste chaque exercice sur une ligne (Nom 3x10) — pas tout en un bloc.
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
        SUIVIS SUGGÉRÉS (optionnel, max 2, bloc séparé) :
        Messages que L'UTILISATEUR enverrait AU coach — pas des questions que tu poses à l'utilisateur.
        FOLLOW_UP_1: [phrase utilisateur→coach, ex: "Propose une variante sans pâtes"]
        FOLLOW_UP_2: [optionnel, ex: "Enregistrer ce dîner dans mon plan"]
        INTERDIT dans FOLLOW_UP : questions coach→user ("T'as fait ta séance ?", "Tu as du riz ?", "T'as un micro-ondes ?").
        Si des ACTION_* suffisent, ne mets pas de FOLLOW_UP.
        """
    }

    private static func deepLinkBlock() -> String {
        """
        LIEN APP (1 seul, fin de réponse) :
        DEEP_LINK: [plan|journal|scan|streak|integration]|[libellé bouton court]
        Exemples : DEEP_LINK: plan|Voir mon journal · DEEP_LINK: scan|Faire mon scan
        """
    }

    private static func contextualActionsBlock(isModify: Bool, isMeal: Bool) -> String {
        if isMeal {
            return """
            ACTIONS CONTEXTUELLES (obligatoire en fin de réponse, max 4) :
            ACTION_1: validateMeal|Valider dans mon plan|[Petit-déjeuner|Déjeuner|Dîner|Collation]
            ACTION_2: modifyMeal|Ajuster ce repas|[créneau]
            ACTION_3: anotherMeal|Autre idée|[créneau]
            ACTION_4: addToShoppingList|Liste de courses|[créneau]
            """
        }
        if isModify {
            return """
            ACTIONS CONTEXTUELLES (obligatoire en fin de réponse) :
            ACTION_1: applyPlanChanges|Appliquer au programme
            ACTION_2: openPlan|Voir mon plan
            """
        }
        return """
        ACTIONS CONTEXTUELLES (si une action concrète dans l'app est possible, max 3) :
        Format : ACTION_N: [kind]|[libellé court]|[payload optionnel]
        Kinds : validateMeal, saveMealDraft, modifyMeal, anotherMeal, addToShoppingList,
        applyPlanChanges, swapWorkout, openPlan, openJournal, takePhoto, followUp
        Exemples :
        ACTION_1: takePhoto|Photographier mes ingrédients
        ACTION_2: followUp|Décrire mon frigo|Voici ce que j'ai :
        ACTION_3: swapWorkout|Changer la séance
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
