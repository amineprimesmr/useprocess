import SwiftUI

struct CoachEveningChecklistCard: View {
    @Bindable private var planStore = WelcomePlanStore.shared
    @Environment(\.appTheme) private var theme

    private var plan: FaceOriginPlan? { planStore.plan }
    private var day: OriginProgramDay? {
        plan.flatMap { OriginPlanPresenter.todayDay(in: $0) }
    }

    var body: some View {
        if let plan, let day {
            VStack(alignment: .leading, spacing: 12) {
                header(plan: plan, day: day)

                PlanDayChronologicalTimeline(
                    day: day,
                    plan: plan,
                    selectedDate: Date(),
                    isEditable: true,
                    onTaskStatusChange: { taskId, dayId, status in
                        WelcomePlanStore.shared.setJournalTaskStatus(status, taskId: taskId, dayId: dayId)
                    }
                )
            }
            .padding(14)
            .background(cardBackground)
        }
    }

    private func header(plan: FaceOriginPlan, day: OriginProgramDay) -> some View {
        let summary = OriginPlanPresenter.journalCompletionSummary(
            plan: plan,
            day: day,
            date: Date()
        )
        let isComplete = OriginPlanPresenter.isDayJournalFilled(plan: plan, day: day)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.onboardingAccent)
                Text("Checklist du soir")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Spacer(minLength: 0)
                if isComplete {
                    Label("Complet", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.45))
                }
            }

            Text(summary.analysis)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(theme.isDark ? Color(red: 0.11, green: 0.11, blue: 0.12) : theme.cardBackgroundStrong)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.cardStroke.opacity(0.45), lineWidth: 0.5)
            }
    }
}
