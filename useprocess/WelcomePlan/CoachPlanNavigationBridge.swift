import Foundation

@MainActor
@Observable
final class CoachPlanNavigationBridge {
    static let shared = CoachPlanNavigationBridge()

    var pendingPrompt: String?
    var pendingFocus: CoachPlanFocus?
    var pendingConversationId: UUID?
    var pendingCheckInPrompt: String?
    var shouldFocusProfileStatistics = false
    var shouldOpenCoach = false
    var shouldOpenPlan = false
    var shouldOpenFood = false
    var shouldOpenMealScan = false
    var focusHydrationCarouselNonce = 0
    var shouldOpenFaceScan = false
    /// Ouvre la capture scan en plein écran (depuis l’accueil) avec auto-start si cadence OK.
    var shouldOpenScanHub = false
    var shouldOpenTracking = false
    var shouldOpenIntegration = false
    var pendingFaceScanHandoff: FaceScanCoachHandoff?
    var pendingMealHandoff: CoachMealHandoff?
    /// Incrémenté à chaque demande d'ouverture coach avec payload en attente (handoff déjà ouvert inclus).
    var coachNavigationNonce = 0

    private func requestCoachNavigation() {
        coachNavigationNonce += 1
        shouldOpenCoach = true
    }

    func openPlan() {
        shouldOpenPlan = true
    }

    func openFood() {
        shouldOpenFood = true
    }

    func openMealScan() {
        shouldOpenMealScan = true
    }

    func focusHydrationOnHome() {
        focusHydrationCarouselNonce += 1
        shouldOpenPlan = true
    }

    func requestHomeFaceScan() {
        if FaceScanHistoryStore.shared.canStartTodayScan {
            ProcessFaceScanDayCoordinator.shared.requestAutoStart()
        }
        shouldOpenScanHub = true
    }

    func openCoach(conversationId: UUID? = nil) {
        pendingConversationId = conversationId
        shouldOpenCoach = true
    }

    func openCoachWithCheckIn(prompt: String) {
        pendingCheckInPrompt = prompt
        shouldOpenCoach = true
    }

    func openProfileStatistics() {
        shouldFocusProfileStatistics = true
    }

    func consumeProfileStatisticsFocus() -> Bool {
        let pending = shouldFocusProfileStatistics
        shouldFocusProfileStatistics = false
        return pending
    }

    func openCoachAfterFaceScan(handoff: FaceScanCoachHandoff) {
        pendingFaceScanHandoff = handoff
        requestCoachNavigation()
    }

    func consumePendingFaceScanHandoff() -> FaceScanCoachHandoff? {
        let handoff = pendingFaceScanHandoff
        pendingFaceScanHandoff = nil
        return handoff
    }

    var hasPendingFaceScanHandoff: Bool {
        pendingFaceScanHandoff != nil
    }

    func openCoachForMeal(
        meal: MealSuggestionContent,
        slot: MealTimeSlot,
        day: OriginProgramDay,
        prompt: String? = nil
    ) {
        pendingMealHandoff = CoachMealHandoff(
            meal: meal,
            slot: slot,
            dayId: day.id,
            dayTitle: day.title,
            dayIndex: day.globalDayIndex
        )
        pendingPrompt = prompt
        shouldOpenCoach = true
    }

    func consumePendingMealHandoff() -> CoachMealHandoff? {
        let handoff = pendingMealHandoff
        pendingMealHandoff = nil
        return handoff
    }

    func openDeepLink(_ action: CoachDeepLinkAction) {
        switch action {
        case .plan, .journal:
            shouldOpenPlan = true
            shouldOpenCoach = true
        case .scan:
            shouldOpenFaceScan = true
            shouldOpenCoach = true
        case .streak:
            openProfileStatistics()
        case .integration:
            shouldOpenIntegration = true
            shouldOpenCoach = true
        }
    }

    func askCoachAboutPlan(focus: CoachPlanFocus) {
        pendingFocus = focus
        pendingPrompt = promptForFocus(focus)
        shouldOpenCoach = true
    }

    func consumePendingFocus() -> CoachPlanFocus? {
        let focus = pendingFocus
        pendingFocus = nil
        return focus
    }

    func consumePendingPrompt() -> String? {
        let prompt = pendingPrompt
        pendingPrompt = nil
        return prompt
    }

    func consumePendingCheckInPrompt() -> String? {
        let prompt = pendingCheckInPrompt
        pendingCheckInPrompt = nil
        return prompt
    }

    private func promptForFocus(_ focus: CoachPlanFocus) -> String {
        switch focus.mode {
        case .ask:
            return AppCopy.t(
                "J'ai une question sur cette partie de mon plan :\n\n[\(focus.sectionTitle)]\n\(focus.sectionContent)\n\nExplique-moi et dis-moi si c'est pertinent pour moi.",
                en: "I have a question about this part of my plan:\n\n[\(focus.sectionTitle)]\n\(focus.sectionContent)\n\nExplain it and tell me if it’s relevant for me."
            )
        case .evaluate:
            return AppCopy.t(
                """
                Évalue cette partie de mon plan personnalisé (pertinence 0–100, garder/modifier/remplacer, pourquoi) :

                [\(focus.sectionTitle)]
                \(focus.sectionContent)
                """,
                en: """
                Evaluate this part of my personalized plan (relevance 0–100, keep/modify/replace, and why):

                [\(focus.sectionTitle)]
                \(focus.sectionContent)
                """
            )
        case .modify:
            return AppCopy.t(
                """
                Je veux modifier cette partie de mon plan. Applique les changements directement dans mon calendrier :

                [\(focus.sectionTitle)]
                \(focus.sectionContent)

                Dis ce que tu changes concrètement (format Petit-déjeuner:/Déjeuner:/Dîner: si nutrition).
                """,
                en: """
                I want to change this part of my plan. Apply the changes directly in my calendar:

                [\(focus.sectionTitle)]
                \(focus.sectionContent)

                Say what you change concretely (Breakfast:/Lunch:/Dinner: format if nutrition).
                """
            )
        }
    }
}
