import Foundation

enum CoachPlanEditor {

    @MainActor
    static func applyCalendarPatch(
        plan: inout FaceOriginPlan,
        sectionPath: String,
        newContent: String,
        userRequest: String,
        coachResponse: String
    ) {
        plan.lastUpdated = Date()
        let mod = OriginPlanModification(
            id: UUID().uuidString,
            createdAt: Date(),
            sectionPath: sectionPath,
            previousSummary: sectionPath,
            userRequest: userRequest,
            coachResponse: coachResponse,
            applied: true
        )
        plan.progress.modifications.insert(mod, at: 0)
        plan.progress.modifications = Array(plan.progress.modifications.prefix(30))
        CoachMemoryStore.shared.recordPlanAdjustment("\(sectionPath) : \(String(newContent.prefix(80)))")
    }

    @MainActor
    static func regenerateCalendarIfNeeded(plan: inout FaceOriginPlan, answers: [String: WelcomePlanAnswer], profile: UnifiedUserProfile?) {
        guard plan.calendar.weeks.isEmpty else { return }
        regenerateCalendar(plan: &plan, answers: answers, profile: profile)
    }

    @MainActor
    static func regenerateCalendar(plan: inout FaceOriginPlan, answers: [String: WelcomePlanAnswer], profile: UnifiedUserProfile?) {
        let gender = profile?.gender ?? .male
        let startedAt = plan.calendar.startedAt ?? plan.createdAt
        plan.calendar = OriginPlanCalendarBuilder.build(from: plan, answers: answers, gender: gender)
        plan.calendar.startedAt = startedAt
    }
}
