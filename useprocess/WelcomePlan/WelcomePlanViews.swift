import SwiftUI

struct WelcomePlanCompactCard: View {
    let plan: FaceOriginPlan

    @Environment(\.appTheme) private var theme

    var body: some View {
        let counts = OriginPlanPresenter.todayTaskCount(in: plan)
        let week = plan.calendar.currentWeekNumber()

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Semaine \(week)/\(plan.totalWeeks)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                if counts.total > 0 {
                    Text("\(counts.done)/\(counts.total) tâches")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.onboardingAccent)
                }
            }

            Text(OriginPlanPresenter.oneLineSummary(plan))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)
                .lineLimit(2)

            HStack(spacing: 6) {
                ForEach(OriginPlanPresenter.impactPriorities(from: plan, limit: 3)) { pillar in
                    Text(shortPillar(pillar.pillar))
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(theme.coachUserBubble.opacity(0.55), in: Capsule())
                }
            }
        }
        .padding(14)
        .background(theme.coachUserBubble.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func shortPillar(_ name: String) -> String {
        if name.contains("Hormones") { return "Hormones" }
        if name.contains("Entraînement") { return "Sport" }
        if name.contains("Posture") { return "Posture" }
        if name.contains("Maxillaire") { return "Mâchoire" }
        return "Visage"
    }
}
