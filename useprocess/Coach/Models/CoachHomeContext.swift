import Foundation

struct CoachHomeSuggestion: Identifiable, Equatable, Sendable {
    let id: String
    /// Titre court sur la carte.
    let label: String
    let subtitle: String
    let icon: String
    /// Prompt envoyé à l'IA.
    let prompt: String
    /// Texte affiché dans la bulle utilisateur (question naturelle).
    let userMessage: String
}

enum CoachHomePromptKind: Equatable {
    case greeting
    case scanDue(firstScan: Bool)
}

struct CoachHomePrompt: Equatable {
    let kind: CoachHomePromptKind
    let greetingText: String
    let primaryActionTitle: String?
    /// Masque la barre de saisie au profit d’un bouton d’action.
    let replacesChatInput: Bool
    let suggestions: [CoachHomeSuggestion]

    var requiresScanBeforeChat: Bool {
        if case .scanDue = kind { return true }
        return false
    }
}

enum CoachHomeContext {
    private static let answerStyle = """
     Réponds en français, tutoiement, concret.
    Si tu listes des repas, étapes ou options, mets chaque point sur une nouvelle ligne avec un tiret (– ).
    Pas de markdown (** #), pas de fiche repas structurée.
    """

    static func isLegacyWelcomeMessage(_ message: CoachMessage) -> Bool {
        guard message.role == .assistant else { return false }
        let text = message.text
        return text.localizedCaseInsensitiveContains("je suis ton coach useprocess")
            || text.localizedCaseInsensitiveContains("coach useprocess (")
            || (text.localizedCaseInsensitiveContains("salut") && text.localizedCaseInsensitiveContains("pose-moi une question"))
    }

    static func sanitizedMessages(_ messages: [CoachMessage]) -> [CoachMessage] {
        messages.filter { !isLegacyWelcomeMessage($0) }
    }

    @MainActor
    static func resolve(
        profile: UnifiedUserProfile?,
        scanStore: FaceScanHistoryStore? = nil
    ) -> CoachHomePrompt {
        let scanStore = scanStore ?? FaceScanHistoryStore.shared
        let trimmedName = profile?.firstName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasName = !trimmedName.isEmpty
        let scanDue = scanStore.isScanDue
        let hasPreviousScan = scanStore.latestResult != nil

        let kind: CoachHomePromptKind = scanDue
            ? .scanDue(firstScan: !hasPreviousScan)
            : .greeting

        if scanDue {
            let greeting = hasName ? "Salut \(trimmedName)." : "Salut."
            let scanSuggestion = suggestion(
                id: "scan",
                title: "Scan visage",
                subtitle: hasPreviousScan ? "Suivi debloat · 30 s" : "Premier scan · 30 s",
                icon: "📸",
                question: hasPreviousScan
                    ? "Analyse ma progression debloat avec mon scan du jour."
                    : "Guide-moi pour mon premier scan visage."
            )
            var daySuggestions = buildSuggestions(
                profile: profile,
                context: UserContextBuilder.build(profile: profile),
                plan: WelcomePlanStore.shared.plan
            )
            daySuggestions.insert(scanSuggestion, at: 0)
            return CoachHomePrompt(
                kind: kind,
                greetingText: greeting,
                primaryActionTitle: nil,
                replacesChatInput: false,
                suggestions: Array(daySuggestions.prefix(3))
            )
        }

        let greeting = hasName
            ? "Salut \(trimmedName), quoi de neuf ?"
            : "Salut, quoi de neuf ?"
        return CoachHomePrompt(
            kind: kind,
            greetingText: greeting,
            primaryActionTitle: nil,
            replacesChatInput: false,
            suggestions: buildSuggestions(
                profile: profile,
                context: UserContextBuilder.build(profile: profile),
                plan: WelcomePlanStore.shared.plan
            )
        )
    }

    /// Carte affichée + prompt IA (question + contexte discret).
    private static func suggestion(
        id: String,
        title: String,
        subtitle: String,
        icon: String,
        question: String,
        hint: String? = nil
    ) -> CoachHomeSuggestion {
        let prompt: String
        if let hint, !hint.isEmpty {
            prompt = "\(question) Contexte : \(hint).\(answerStyle)"
        } else {
            prompt = "\(question)\(answerStyle)"
        }
        return CoachHomeSuggestion(
            id: id,
            label: title,
            subtitle: subtitle,
            icon: icon,
            prompt: prompt,
            userMessage: question
        )
    }

    @MainActor
    private static func buildSuggestions(
        profile: UnifiedUserProfile?,
        context: CoachUserContext,
        plan: FaceOriginPlan?
    ) -> [CoachHomeSuggestion] {
        if let plan, let day = OriginPlanPresenter.todayDay(in: plan) {
            return planDaySuggestions(day: day, plan: plan, context: context)
        }
        return profileDaySuggestions(profile: profile, context: context)
    }

    private static func planDaySuggestions(
        day: OriginProgramDay,
        plan: FaceOriginPlan,
        context: CoachUserContext
    ) -> [CoachHomeSuggestion] {
        var items: [CoachHomeSuggestion] = []

        items.append(
            suggestion(
                id: "today",
                title: "Mon focus du jour",
                subtitle: day.title,
                icon: "🎯",
                question: "C'est quoi mon focus aujourd'hui sur mon plan debloat ?",
                hint: "Jour du plan : \(day.title)"
            )
        )

        let cardio = DebloatCardioDayCatalog.session()
        items.append(
            suggestion(
                id: "cardio-circuit",
                title: "Cardio et Circuit",
                subtitle: "\(cardio.title) · \(cardio.minutes) min",
                icon: "🏃",
                question: "Explique-moi mon cardio du jour et le circuit posture — comment bien les faire pour le debloat ?",
                hint: "\(cardio.title), \(cardio.minutes) min · \(DebloatCardioDayCatalog.frequencyCaption)"
            )
        )

        let nutritionLine = OriginPlanPresenter.nutritionOneLiner(day: day, plan: plan)
        items.append(
            suggestion(
                id: "meals",
                title: "Mes repas",
                subtitle: "Ce que le plan prévoit",
                icon: "🍽️",
                question: "Quels sont mes repas prévus aujourd'hui, et pourquoi ils collent au debloat ?",
                hint: nutritionLine
            )
        )

        if items.count < 3 {
            let sleepHours = context.health?.sleepHours.map { String(format: "%.1f h", $0) } ?? "—"
            items.append(
                suggestion(
                    id: "sleep",
                    title: "Sommeil",
                    subtitle: "Préparer ce soir",
                    icon: "😴",
                    question: "Comment je prépare mon sommeil ce soir pour demain ?",
                    hint: "Coucher \(day.sleep.targetBedtime), réveil \(day.sleep.targetWake), besoin \(String(format: "%.1f", day.sleep.targetHours)) h, sommeil récent \(sleepHours)"
                )
            )
        }

        return Array(items.prefix(3))
    }

    private static func profileDaySuggestions(
        profile: UnifiedUserProfile?,
        context: CoachUserContext
    ) -> [CoachHomeSuggestion] {
        let goal = profile?.weightGoal?.rawValue ?? "forme"
        let sleepHours = context.health?.sleepHours.map { String(format: "%.1f h", $0) } ?? "—"
        let sportsLine = profile?.sports.prefix(2).map(\.name).joined(separator: ", ") ?? "—"

        return [
            suggestion(
                id: "today",
                title: "Par où je commence ?",
                subtitle: "Priorité du moment",
                icon: "🎯",
                question: "Par où je commence aujourd'hui pour avancer sur mon objectif ?",
                hint: "Objectif \(goal)"
            ),
            suggestion(
                id: "cardio-circuit",
                title: "Cardio et Circuit",
                subtitle: sportsLine == "—" ? DebloatCardioDayCatalog.frequencyCaption : sportsLine,
                icon: "🏃",
                question: "Que me conseilles-tu comme cardio léger et circuit posture aujourd'hui pour le debloat ?",
                hint: "Cardio du jour · \(DebloatCardioDayCatalog.frequencyCaption) · sports : \(sportsLine)"
            ),
            suggestion(
                id: "meals",
                title: "Nutrition",
                subtitle: "Repas & debloat",
                icon: "🍽️",
                question: "Comment je mange aujourd'hui pour rester aligné avec le debloat ?",
                hint: "Objectif \(goal), sommeil récent \(sleepHours)"
            ),
        ]
    }
}
