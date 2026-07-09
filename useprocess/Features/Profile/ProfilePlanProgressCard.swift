import SwiftUI

/// Durée et progression du plan personnalisé — stats profil.
struct ProfilePlanProgressCard: View {
    @Environment(\.appTheme) private var theme

    let snapshot: PlanProgressSnapshot

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ProfileMetricChartLayout.cardRadius, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow

            if snapshot.hasPlan {
                progressBar(
                    value: snapshot.timeProgress,
                    tint: Color(hex: "aeb2fa")
                )

                if !snapshot.milestones.isEmpty {
                    milestonesSection
                }

                validationRow

                if let note = snapshot.latestEvolutionNote {
                    evolutionNote(note)
                }
            }
        }
        .padding(ProfileMetricChartLayout.cardPadding)
        .background { cardBackground }
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
    }

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plan personnalisé")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.secondaryText)

                    if snapshot.hasPlan {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(snapshot.totalWeeks)")
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.primaryText)
                                .monospacedDigit()

                            Text(snapshot.totalWeeks <= 1 ? "semaine" : "semaines")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(theme.secondaryText)
                        }

                        if let endDate = snapshot.estimatedEndDate {
                            Text("Objectif · \(Self.formatEndDate(endDate))")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "aeb2fa"))
                        }
                    }
                }

                Spacer(minLength: 8)

                if snapshot.hasPlan {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(snapshot.weeksLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.primaryText)

                        if snapshot.durationAdjustmentDays != 0 {
                            Text(adjustmentLabel)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(
                                    snapshot.durationAdjustmentDays < 0
                                        ? Color(red: 0.35, green: 0.78, blue: 0.45)
                                        : Color(red: 1.0, green: 0.72, blue: 0.28)
                                )
                        }
                    }
                }
            }

            Text(snapshot.headline)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.primaryText)

            Text(snapshot.subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var adjustmentLabel: String {
        let weeks = ProcessDurationFormat.weekCount(fromDays: abs(snapshot.durationAdjustmentDays))
        let signed = snapshot.durationAdjustmentDays > 0 ? "+\(weeks)" : "-\(weeks)"
        return "\(signed) sem. ajustées"
    }

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let mode = snapshot.trajectoryMode {
                Text(mode.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }

            ForEach(snapshot.milestones, id: \.id) { milestone in
                milestoneRow(milestone)
            }
        }
    }

    private func milestoneRow(_ milestone: PlanMilestoneProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label {
                    Text(milestone.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                } icon: {
                    Image(systemName: milestone.id == "debloat" ? "drop.fill" : "scalemass.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(
                            milestone.isComplete
                                ? Color(red: 0.35, green: 0.78, blue: 0.45)
                                : milestone.isActive
                                    ? Color(hex: "aeb2fa")
                                    : theme.secondaryText
                        )
                }

                Spacer()

                if milestone.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.45))
                } else if milestone.isActive {
                    let elapsedWeeks = ProcessDurationFormat.weekCount(fromDays: milestone.elapsedDays)
                    let targetWeeks = ProcessDurationFormat.weekCount(fromDays: milestone.targetDays)
                    Text("S\(elapsedWeeks)/\(targetWeeks)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: "aeb2fa"))
                        .monospacedDigit()
                }
            }

            progressBar(
                value: milestone.progress,
                tint: milestone.id == "debloat"
                    ? Color(red: 0.45, green: 0.72, blue: 0.95)
                    : Color(hex: "aeb2fa")
            )

            if let date = milestone.estimatedDate, !milestone.isComplete {
                Text("Cible · \(Self.formatEndDate(date))")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private var validationRow: some View {
        HStack(spacing: 12) {
            metricPill(
                icon: "checkmark.circle.fill",
                title: "\(snapshot.validatedDays)",
                subtitle: "validés"
            )

            metricPill(
                icon: "flame.fill",
                title: "\(snapshot.currentStreak)",
                subtitle: "série"
            )

            if snapshot.elapsedProgramDays > 0 {
                metricPill(
                    icon: "calendar",
                    title: "S\(snapshot.currentWeek)",
                    subtitle: "/ \(snapshot.totalWeeks)"
                )
            }
        }
    }

    private func metricPill(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.secondaryText)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.primaryText.opacity(theme.isDark ? 0.06 : 0.04))
        )
    }

    private func progressBar(value: Double, tint: Color) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.primaryText.opacity(theme.isDark ? 0.08 : 0.06))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.85), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, geometry.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 8)
    }

    private func evolutionNote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(hex: "aeb2fa"))
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if #available(iOS 26.0, *) {
            cardShape.fill(.clear).glassEffect(.regular, in: cardShape)
        } else {
            cardShape
                .fill(theme.isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.92))
                .overlay {
                    cardShape.strokeBorder(theme.primaryText.opacity(0.06), lineWidth: 1)
                }
        }
    }

    private static func formatEndDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
}
