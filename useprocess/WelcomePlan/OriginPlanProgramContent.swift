import SwiftUI

struct OriginPlanHeaderCard: View {
    let plan: FaceOriginPlan
    @Environment(\.appTheme) private var theme

    var body: some View {
        let counts = OriginPlanPresenter.todayTaskCount(in: plan)
        let week = plan.calendar.currentWeekNumber()

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mon plan · S\(week)/\(plan.totalWeeks)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                    if let snapshot = plan.assessmentSnapshot {
                        Text(snapshot.archetype.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.onboardingAccent)
                    }
                    Text(OriginPlanPresenter.phaseHeadline(plan))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                }
                Spacer()
                if counts.total > 0 {
                    Text("\(counts.done)/\(counts.total)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(theme.onboardingAccent)
                }
            }

            Text(OriginPlanPresenter.oneLineSummary(plan))
                .font(.headline)
                .foregroundStyle(theme.onboardingAccent)
                .fixedSize(horizontal: false, vertical: true)

            if !plan.successCriteria.isEmpty {
                successCriteriaRow
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.coachUserBubble.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var successCriteriaRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Objectifs")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
            ForEach(plan.successCriteria.prefix(3)) { criterion in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "target")
                        .font(.caption2)
                        .foregroundStyle(theme.onboardingAccent)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(criterion.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.primaryText)
                        Text(criterion.detail)
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}

struct OriginPlanSuccessCriteriaCard: View {
    let criteria: [OriginSuccessCriterion]
    @Environment(\.appTheme) private var theme

    var body: some View {
        if criteria.isEmpty { EmptyView() }
        else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Objectifs du protocole")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                ForEach(criteria) { criterion in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: icon(for: criterion))
                            .foregroundStyle(theme.onboardingAccent)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(criterion.label)
                                .font(.caption.weight(.semibold))
                            Text(criterion.detail)
                                .font(.caption2)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HealthHubDesign.surfaceCard(theme: theme))
        }
    }

    private func icon(for criterion: OriginSuccessCriterion) -> String {
        switch criterion.metricKey {
        case "puffinessScore": return "face.smiling"
        case "skinClarityScore": return "sparkles"
        case "bodyFatPercent": return "figure.strengthtraining.traditional"
        case "baselineScan": return "camera.fill"
        default: return "checkmark.circle"
        }
    }
}
