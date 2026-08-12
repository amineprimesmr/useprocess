import SwiftUI

/// Cardio et Circuit sur la page Réglages — même UI que la routine matinale sur l’accueil.
struct ProcessSettingsPlanProgramSections: View {
    @Bindable private var planStore = WelcomePlanStore.shared

    private var plan: FaceOriginPlan? { planStore.plan }

    private var programContext: (plan: FaceOriginPlan, day: OriginProgramDay, date: Date)? {
        guard let plan else { return nil }
        let date = OriginPlanPresenter.preferredHomeDate(in: plan)
        guard let day = OriginPlanPresenter.programDay(in: plan, for: date) else { return nil }
        return (plan, day, date)
    }

    var body: some View {
        if let context = programContext {
            PlanTrainingDaySection(
                plan: context.plan,
                day: context.day,
                selectedDate: context.date,
                isEditable: OriginPlanPresenter.isEditableJournalDay(
                    dayId: context.day.id,
                    in: context.plan
                )
            )
        }
    }
}
