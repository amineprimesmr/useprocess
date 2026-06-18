import Foundation

struct CoachHomeSuggestion: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let prompt: String
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
}

enum CoachHomeContext {
    private static let answerStyle = " Réponds en 2-3 phrases, tutoiement, concret, sans markdown."

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
        scanStore: FaceScanHistoryStore = .shared
    ) -> CoachHomePrompt {
        let trimmedName = profile?.firstName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasName = !trimmedName.isEmpty
        let scanDue = scanStore.isScanDue
        let hasPreviousScan = scanStore.latestResult != nil
        let plan = WelcomePlanStore.shared.plan
        let context = UserContextBuilder.build(profile: profile)

        let kind: CoachHomePromptKind = scanDue
            ? .scanDue(firstScan: !hasPreviousScan)
            : .greeting

        let suggestions = buildSuggestions(
            profile: profile,
            context: context,
            plan: plan
        )

        if scanDue {
            let greeting: String
            let buttonTitle: String
            if hasPreviousScan {
                greeting = hasName
                    ? "Salut \(trimmedName). Tu n'as pas encore fait ton scan du jour."
                    : "Salut. Tu n'as pas encore fait ton scan du jour."
                buttonTitle = "Faire mon scan"
            } else {
                greeting = hasName
                    ? "Salut \(trimmedName). On commence par ton premier scan ?"
                    : "Salut. On commence par ton premier scan ?"
                buttonTitle = "Faire mon premier scan"
            }
            return CoachHomePrompt(
                kind: kind,
                greetingText: greeting,
                primaryActionTitle: buttonTitle,
                replacesChatInput: true,
                suggestions: suggestions
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
            suggestions: suggestions
        )
    }

    /// Question affichée dans le chat + prompt IA (question + contexte discret).
    private static func suggestion(id: String, question: String, hint: String? = nil) -> CoachHomeSuggestion {
        let prompt: String
        if let hint, !hint.isEmpty {
            prompt = "\(question) Contexte : \(hint).\(answerStyle)"
        } else {
            prompt = "\(question)\(answerStyle)"
        }
        return CoachHomeSuggestion(id: id, label: question, prompt: prompt)
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

        if let training = day.training {
            items.append(
                suggestion(
                    id: "training",
                    question: "C'est quoi ma séance aujourd'hui ?",
                    hint: "\(training.sessionName), \(training.durationMinutes) min, readiness \(context.health?.readinessScore.map(String.init) ?? "—")/100"
                )
            )
        } else {
            items.append(
                suggestion(
                    id: "training-rest",
                    question: "Pas de séance aujourd'hui, je fais quoi ?",
                    hint: "Jour protocole : \(day.title)"
                )
            )
        }

        let nutritionLine = OriginPlanPresenter.nutritionOneLiner(day: day, plan: plan)
        let mealQuestion: String = {
            if day.nutrition.isOMAD || plan.nutritionProtocol.mealPlanStyle == .omad {
                return "Je mange quoi aujourd'hui ?"
            }
            if !day.nutrition.lunch.isEmpty { return "C'est quoi mon déjeuner ?" }
            if !day.nutrition.dinner.isEmpty { return "C'est quoi mon dîner ?" }
            return "Je mange quoi au prochain repas ?"
        }()
        items.append(
            suggestion(
                id: "meal",
                question: mealQuestion,
                hint: nutritionLine
            )
        )

        if let faceTask = day.face.first?.title, !faceTask.isEmpty {
            items.append(
                suggestion(
                    id: "face-routine",
                    question: "C'est quoi ma routine visage ce soir ?",
                    hint: faceTask
                )
            )
        } else {
            items.append(
                suggestion(
                    id: "sleep",
                    question: "Comment je prépare mon sommeil ce soir ?",
                    hint: "Coucher \(day.sleep.targetBedtime), réveil \(day.sleep.targetWake), \(String(format: "%.1f", day.sleep.targetHours)) h"
                )
            )
        }

        return Array(items.prefix(3))
    }

    private static func profileDaySuggestions(
        profile: UnifiedUserProfile?,
        context: CoachUserContext
    ) -> [CoachHomeSuggestion] {
        let sportsLine = profile?.sports.prefix(2).map(\.name).joined(separator: ", ") ?? "—"
        let goal = profile?.weightGoal?.rawValue ?? "forme"
        let sessions = profile?.sessionsPerWeek.map { "\($0) séances/sem" } ?? "—"
        let readiness = context.health?.readinessScore.map(String.init) ?? "—"
        let readinessWord = context.health?.readinessLabel ?? "—"
        let sleepHours = context.health?.sleepHours.map { String(format: "%.1f h", $0) } ?? "—"
        let nutrition = profile?.nutritionProfile?.nutritionQuality?.rawValue ?? "—"

        return [
            suggestion(
                id: "training",
                question: "C'est quoi mon entraînement aujourd'hui ?",
                hint: "\(sportsLine), \(sessions), objectif \(goal), readiness \(readiness)/100"
            ),
            suggestion(
                id: "meal",
                question: "Je mange quoi au prochain repas ?",
                hint: "Objectif \(goal), habitudes \(nutrition)"
            ),
            suggestion(
                id: "today",
                question: "Qu'est-ce que je fais aujourd'hui ?",
                hint: "Readiness \(readiness)/100 (\(readinessWord)), sommeil récent \(sleepHours)"
            ),
        ]
    }
}
