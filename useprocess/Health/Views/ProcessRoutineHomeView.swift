import SwiftUI

/// Onglet Routine — circuit lymphatique (visage) + cardio / circuit.
struct ProcessRoutineHomeView: View {
    @Binding var selectedSection: ProcessMainSection
    var isTabActive: Bool = true

    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var planStore = WelcomePlanStore.shared

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    private var livePlan: FaceOriginPlan? { planStore.plan }

    private var programDay: OriginProgramDay? {
        guard let plan = livePlan else { return nil }
        return OriginPlanPresenter.programDay(in: plan, for: selectedDate)
            ?? OriginPlanPresenter.todayDay(in: plan, date: selectedDate)
    }

    private var isDayEditable: Bool {
        guard let plan = livePlan, let day = programDay else { return false }
        return OriginPlanPresenter.isEditableJournalDay(dayId: day.id, in: plan)
    }

    var body: some View {
        processMainScrollableChrome(
            selectedSection: $selectedSection,
            pageSection: .routine
        ) {
            VStack(alignment: .leading, spacing: PlanHomeSectionDesign.sectionSpacing) {
                header

                if let plan = livePlan, let day = programDay {
                    PlanFaceDaySection(plan: plan, day: day)

                    PlanTrainingDaySection(
                        plan: plan,
                        day: day,
                        selectedDate: selectedDate,
                        isEditable: isDayEditable
                    )
                } else {
                    emptyState
                }
            }
            .padding()
            .padding(.bottom, ProcessIGTabMetrics.tabBarOverlayClearance + 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .processClearUIKitHostingBackground()
        .onAppear {
            syncSelectedDate()
        }
        .onChange(of: livePlan?.id) { _, _ in
            syncSelectedDate()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, isTabActive else { return }
            syncSelectedDate()
        }
    }

    private var header: some View {
        Text(AppCopy.t("Routine", en: "Routine"))
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(theme.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppCopy.t(
                "Tes routines apparaîtront ici une fois ton plan prêt.",
                en: "Your routines will show up here once your plan is ready."
            ))
            .font(.subheadline)
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private func syncSelectedDate() {
        guard let plan = livePlan else { return }
        selectedDate = OriginPlanPresenter.preferredHomeDate(in: plan)
    }
}
