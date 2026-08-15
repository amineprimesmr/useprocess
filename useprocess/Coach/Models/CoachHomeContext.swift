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
    @MainActor
    private static var answerStyle: String {
        AppCopy.t(
            """
             Réponds en français, tutoiement, concret.
            Si tu listes des repas, étapes ou options, mets chaque point sur une nouvelle ligne avec un tiret (– ).
            Pas de markdown (** #), pas de fiche repas structurée.
            """,
            en: """
             Reply in American English, concrete and direct.
            If you list meals, steps, or options, put each point on a new line with a dash (– ).
            No markdown (** #), no structured meal sheet.
            """
        )
    }

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
            let greeting = hasName
                ? AppCopy.t("Salut \(trimmedName).", en: "Hi \(trimmedName).")
                : AppCopy.t("Salut.", en: "Hi.")
            let scanSuggestion = suggestion(
                id: "scan",
                title: AppCopy.t("Scan visage", en: "Face scan"),
                subtitle: hasPreviousScan
                    ? AppCopy.t("Suivi debloat · 30 s", en: "Debloat check-in · 30 s")
                    : AppCopy.t("Premier scan · 30 s", en: "First scan · 30 s"),
                icon: "📸",
                question: hasPreviousScan
                    ? AppCopy.t(
                        "Analyse ma progression debloat avec mon scan du jour.",
                        en: "Analyze my debloat progress with today's scan."
                    )
                    : AppCopy.t(
                        "Guide-moi pour mon premier scan visage.",
                        en: "Guide me through my first face scan."
                    )
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
            ? AppCopy.t("Salut \(trimmedName), quoi de neuf ?", en: "Hi \(trimmedName), what's up?")
            : AppCopy.t("Salut, quoi de neuf ?", en: "Hi, what's up?")
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
    @MainActor
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
            let contextLabel = AppCopy.t("Contexte", en: "Context")
            prompt = "\(question) \(contextLabel) : \(hint).\(answerStyle)"
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

    @MainActor
    private static func planDaySuggestions(
        day: OriginProgramDay,
        plan: FaceOriginPlan,
        context: CoachUserContext
    ) -> [CoachHomeSuggestion] {
        var items: [CoachHomeSuggestion] = []

        items.append(
            suggestion(
                id: "today",
                title: AppCopy.t("Mon focus du jour", en: "My focus today"),
                subtitle: day.title,
                icon: "🎯",
                question: AppCopy.t(
                    "C'est quoi mon focus aujourd'hui sur mon plan debloat ?",
                    en: "What's my focus today on my debloat plan?"
                ),
                hint: AppCopy.t("Jour du plan : \(day.title)", en: "Plan day: \(day.title)")
            )
        )

        let cardio = DebloatCardioDayCatalog.session()
        items.append(
            suggestion(
                id: "cardio-circuit",
                title: AppCopy.t("Cardio et Circuit", en: "Cardio & Circuit"),
                subtitle: cardio.prescriptionLine,
                icon: "🏃",
                question: AppCopy.t(
                    "Explique-moi ma marche inclinée (durée, pente, allure) et le circuit posture pour le debloat.",
                    en: "Explain my incline walk (duration, incline, pace) and the posture circuit for debloat."
                ),
                hint: "\(cardio.title) · \(cardio.prescriptionLine) · \(DebloatCardioDayCatalog.frequencyCaption)"
            )
        )

        let nutritionLine = OriginPlanPresenter.nutritionOneLiner(day: day, plan: plan)
        items.append(
            suggestion(
                id: "meals",
                title: AppCopy.t("Mes repas", en: "My meals"),
                subtitle: AppCopy.t("Ce que le plan prévoit", en: "What the plan includes"),
                icon: "🍽️",
                question: AppCopy.t(
                    "Quels sont mes repas prévus aujourd'hui, et pourquoi ils collent au debloat ?",
                    en: "What meals are planned for today, and why do they fit the debloat plan?"
                ),
                hint: nutritionLine
            )
        )

        if items.count < 3 {
            let sleepHours = context.health?.sleepHours.map { String(format: "%.1f h", $0) } ?? "—"
            items.append(
                suggestion(
                    id: "sleep",
                    title: AppCopy.t("Sommeil", en: "Sleep"),
                    subtitle: AppCopy.t("Préparer ce soir", en: "Prep tonight"),
                    icon: "😴",
                    question: AppCopy.t(
                        "Comment je prépare mon sommeil ce soir pour demain ?",
                        en: "How should I prepare my sleep tonight for tomorrow?"
                    ),
                    hint: AppCopy.t(
                        "Coucher \(day.sleep.targetBedtime), réveil \(day.sleep.targetWake), besoin \(String(format: "%.1f", day.sleep.targetHours)) h, sommeil récent \(sleepHours)",
                        en: "Bedtime \(day.sleep.targetBedtime), wake \(day.sleep.targetWake), need \(String(format: "%.1f", day.sleep.targetHours)) h, recent sleep \(sleepHours)"
                    )
                )
            )
        }

        return Array(items.prefix(3))
    }

    @MainActor
    private static func profileDaySuggestions(
        profile: UnifiedUserProfile?,
        context: CoachUserContext
    ) -> [CoachHomeSuggestion] {
        let goal = profile?.weightGoal?.title ?? AppCopy.t("forme", en: "fitness")
        let sleepHours = context.health?.sleepHours.map { String(format: "%.1f h", $0) } ?? "—"
        let sportsLine = profile?.sports.prefix(2).map { OnboardingSportCatalog.localizedName($0.name) }.joined(separator: ", ")
            ?? "—"

        return [
            suggestion(
                id: "today",
                title: AppCopy.t("Par où je commence ?", en: "Where do I start?"),
                subtitle: AppCopy.t("Priorité du moment", en: "Priority right now"),
                icon: "🎯",
                question: AppCopy.t(
                    "Par où je commence aujourd'hui pour avancer sur mon objectif ?",
                    en: "Where should I start today to move toward my goal?"
                ),
                hint: AppCopy.t("Objectif \(goal)", en: "Goal \(goal)")
            ),
            suggestion(
                id: "cardio-circuit",
                title: AppCopy.t("Cardio et Circuit", en: "Cardio & Circuit"),
                subtitle: sportsLine == "—" ? DebloatCardioDayCatalog.frequencyCaption : sportsLine,
                icon: "🏃",
                question: AppCopy.t(
                    "Que me conseilles-tu comme cardio léger et circuit posture aujourd'hui pour le debloat ?",
                    en: "What light cardio and posture circuit do you recommend today for debloat?"
                ),
                hint: AppCopy.t(
                    "Cardio du jour · \(DebloatCardioDayCatalog.frequencyCaption) · sports : \(sportsLine)",
                    en: "Today's cardio · \(DebloatCardioDayCatalog.frequencyCaption) · sports: \(sportsLine)"
                )
            ),
            suggestion(
                id: "meals",
                title: AppCopy.t("Nutrition", en: "Nutrition"),
                subtitle: AppCopy.t("Repas & debloat", en: "Meals & debloat"),
                icon: "🍽️",
                question: AppCopy.t(
                    "Comment je mange aujourd'hui pour rester aligné avec le debloat ?",
                    en: "How should I eat today to stay aligned with the debloat plan?"
                ),
                hint: AppCopy.t(
                    "Objectif \(goal), sommeil récent \(sleepHours)",
                    en: "Goal \(goal), recent sleep \(sleepHours)"
                )
            ),
        ]
    }
}
