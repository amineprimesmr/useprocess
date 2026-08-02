import Foundation

/// Construit le system prompt Process Intelligence (personnalité, mémoire).
@MainActor
enum CoachIntelligencePromptBuilder {

    static func intelligenceBlock(isModify: Bool) -> String {
        guard CoachIntelligenceSettingsStore.shared.isEnabled else { return "" }

        var parts: [String] = ["\nPROCESS INTELLIGENCE — ACTIF"]
        parts.append(personalityBlock())
        parts.append(behaviorBlock(isModify: isModify))

        if CoachIntelligenceSettingsStore.shared.showsSuggestedFollowUps, !isModify {
            parts.append(followUpBlock())
        }

        parts.append(contextualActionsBlock(isModify: isModify))
        parts.append(memoryUpdateBlock())
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
            - Analytique, cite les chiffres du contexte (sommeil, HRV, pas, scan visage, jour protocole).
            - Explique le « pourquoi » en 1 phrase max.
            - N’invente jamais de score « readiness » — ce concept n’existe pas dans Process.
            """
        case .directCoach:
            return """
            PERSONNALITÉ — Coach direct (Commander) :
            - Très concis, impératif bienveillant, zéro fluff.
            - Dis clairement quoi faire maintenant et pourquoi c'est la priorité.
            - N’utilise jamais le mot readiness.
            """
        case .warmGuide:
            return """
            PERSONNALITÉ — Guide bienveillant (Friend) :
            - Ton chaleureux, encourage la régularité sans culpabiliser.
            - Valide l'effort avant de conseiller la suite.
            - N’utilise jamais le mot readiness.
            """
        case .guardian:
            return """
            PERSONNALITÉ — Guardian :
            - Calme, long terme, protège la santé avant la performance.
            - Si sommeil faible, HRV basse ou fatigue scan → priorise récupération.
            - N’utilise jamais le mot readiness.
            """
        }
    }

    private static func behaviorBlock(isModify: Bool) -> String {
        if isModify { return "" }
        return """
        COMPORTEMENT PROCESS :
        - Discussion fluide avec le plan debloat comme contexte — pas de réponses préfabriquées.
        - Ne jamais inventer une métrique absente du contexte.
        - INTERDIT : readiness, fiches repas structurées (MEAL_NAME / ITEM_*), boutons d'action inutiles.
        - INTERDIT : DEEP_LINK, ARTIFACT, FOOD_LOG, format carte repas.
        - Mise en page : si plusieurs repas / options / étapes → une ligne par point avec tiret (– ).
        - Pose tes questions DANS le texte visible. Pas de markdown (** #).
        - Cite au moins 1 data réelle quand disponible (sommeil, pas, jour protocole, scan visage).
        """
    }

    private static func followUpBlock() -> String {
        """
        SUIVIS SUGGÉRÉS (recommandé, max 2, bloc séparé) :
        Messages naturels que L'UTILISATEUR enverrait AU coach, liés à ta réponse.
        FOLLOW_UP_1: [ex: Je n'ai pas d'avocat, par quoi je peux le remplacer au déjeuner ?]
        FOLLOW_UP_2: [ex: Et si je n'ai que 20 minutes ce midi ?]
        Règles : phrase complète, utile, concrète. Pas de questions coach→user.
        INTERDIT : « Autre idée », « Enregistrer », formulations vagues.
        N'ajoute AUCUN ACTION_*.
        """
    }

    private static func contextualActionsBlock(isModify: Bool) -> String {
        if isModify {
            return """
            ACTIONS CONTEXTUELLES (obligatoire en fin de réponse) :
            ACTION_1: applyPlanChanges|Appliquer au programme
            """
        }
        return """
        ACTIONS CONTEXTUELLES :
        - Par défaut : n'écris AUCUN ACTION_*.
        - INTERDIT : anotherMeal, addToShoppingList, validateMeal, saveMealDraft, modifyMeal,
          swapWorkout, openPlan, openJournal, takePhoto, followUp, DEEP_LINK.
        - Seul cas autorisé hors modification : aucun — la conversation suffit.
        """
    }

    private static func memoryUpdateBlock() -> String {
        """
        MÉMOIRE AUTO (si info perso nouvelle et utile, max 1 ligne) :
        MEMORY_UPDATE: [goals|identity|lifestyle|preferences|events|healthHistory|mood]|[texte court]
        """
    }
}
