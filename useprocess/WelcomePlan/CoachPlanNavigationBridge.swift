import Foundation

@MainActor
@Observable
final class CoachPlanNavigationBridge {
    static let shared = CoachPlanNavigationBridge()

    var pendingPrompt: String?
    var pendingFocus: CoachPlanFocus?
    var pendingConversationId: UUID?
    var pendingCheckInPrompt: String?
    var pendingEveningChecklist = false
    var shouldOpenEveningCheckIn = false
    var shouldFocusProfileStatistics = false
    var eveningChecklistRefreshNonce = 0
    var shouldOpenCoach = false
    var shouldOpenPlan = false
    var shouldOpenFaceScan = false
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

    func openCoach(conversationId: UUID? = nil) {
        pendingConversationId = conversationId
        shouldOpenCoach = true
    }

    func openCoachWithCheckIn(prompt: String) {
        pendingCheckInPrompt = prompt
        shouldOpenCoach = true
    }

    func openCoachWithEveningChecklist() {
        openEveningCheckIn()
    }

    func openEveningCheckIn() {
        shouldOpenPlan = true
        shouldOpenEveningCheckIn = true
    }

    func openProfileStatistics() {
        shouldFocusProfileStatistics = true
    }

    func consumeProfileStatisticsFocus() -> Bool {
        let pending = shouldFocusProfileStatistics
        shouldFocusProfileStatistics = false
        return pending
    }

    func consumePendingEveningCheckIn() -> Bool {
        let pending = shouldOpenEveningCheckIn
        shouldOpenEveningCheckIn = false
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

    func consumePendingEveningChecklist() -> Bool {
        let pending = pendingEveningChecklist
        pendingEveningChecklist = false
        return pending
    }

    func bumpEveningChecklistRefresh() {
        eveningChecklistRefreshNonce += 1
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
            return "J'ai une question sur cette partie de mon plan :\n\n[\(focus.sectionTitle)]\n\(focus.sectionContent)\n\nExplique-moi et dis-moi si c'est pertinent pour moi."
        case .evaluate:
            return """
            Évalue cette partie de mon plan personnalisé (pertinence 0–100, garder/modifier/remplacer, pourquoi) :

            [\(focus.sectionTitle)]
            \(focus.sectionContent)
            """
        case .modify:
            return """
            Je veux modifier cette partie de mon plan. Applique les changements directement dans mon calendrier :

            [\(focus.sectionTitle)]
            \(focus.sectionContent)

            Dis ce que tu changes concrètement (format Petit-déjeuner:/Déjeuner:/Dîner: si nutrition).
            """
        }
    }
}
