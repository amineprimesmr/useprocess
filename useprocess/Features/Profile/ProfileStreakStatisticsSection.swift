import SwiftUI

/// Trajectoire debloat + streak + bilan du soir — section statistiques du profil.
struct ProfileStreakStatisticsSection: View {
    @Environment(\.appTheme) private var theme

    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var trajectoryStore = ProcessDebloatTrajectoryStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared
    @Bindable private var planProgressStore = ProcessPlanProgressStore.shared
    @Bindable private var planBridge = CoachPlanNavigationBridge.shared
    @Bindable private var session = AppSession.shared

    @State private var showEveningCheckIn = false

    private var snapshot: ProcessStreakSnapshot { streakStore.snapshot }
    private var trajectory: DebloatTrajectorySnapshot { trajectoryStore.snapshot }
    private var planProgress: PlanProgressSnapshot { planProgressStore.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ProfilePlanProgressCard(snapshot: planProgress)
                .padding(.horizontal, ProfileTheme.horizontalPadding)

            ProfileDebloatTrajectoryChart(
                points: trajectory.chartPoints,
                trend: trajectory.trajectoryTrend,
                velocityLabel: trajectory.velocityLabel
            )
            .padding(.horizontal, ProfileTheme.horizontalPadding)

            if session.hasCompletedWelcomePlanChat {
                ProcessEveningCheckInEntryButton {
                    showEveningCheckIn = true
                }
                .padding(.horizontal, ProfileTheme.horizontalPadding)
            }

            streakBlock
                .padding(.horizontal, ProfileTheme.horizontalPadding)
        }
        .onAppear {
            trajectoryStore.sync(from: planStore.plan)
            ProcessEveningCheckInStore.shared.reload()
            if planBridge.consumePendingEveningCheckIn() {
                showEveningCheckIn = true
            }
        }
        .onChange(of: planBridge.shouldOpenEveningCheckIn) { _, should in
            guard should else { return }
            planBridge.shouldOpenEveningCheckIn = false
            showEveningCheckIn = true
        }
        .sheet(isPresented: $showEveningCheckIn) {
            ProcessEveningCheckInSheet()
        }
    }

    private var streakBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerBlock
            weekRow
            milestoneRow

            if let verdict = snapshot.todayVerdict, snapshot.isTodayComplete {
                Text(verdict.shortLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(verdict.chartColor)
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Streak")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(ProcessStreakPalette.flame)

                Text("\(snapshot.currentStreak)")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()

                Text("jour\(snapshot.currentStreak > 1 ? "s" : "")")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }

            Text("Record : \(snapshot.longestStreak) jour\(snapshot.longestStreak > 1 ? "s" : "")")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.secondaryText)
        }
    }

    private var weekRow: some View {
        HStack(spacing: 8) {
            ForEach(snapshot.calendarWeek) { day in
                VStack(spacing: 6) {
                    Text(day.weekdaySymbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.secondaryText)

                    ZStack {
                        Circle()
                            .fill(dayFill(for: day))
                            .frame(width: 34, height: 34)

                        if day.isComplete {
                            Image(systemName: dayIcon(for: day))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        } else if !day.isFuture {
                            Text("\(day.dayOfMonth)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.primaryText)
                        } else {
                            Text("\(day.dayOfMonth)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.secondaryText.opacity(0.45))
                        }
                    }
                    .overlay {
                        if day.isToday {
                            Circle()
                                .strokeBorder(ProcessStreakPalette.flame.opacity(0.85), lineWidth: 1.5)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }

    private var milestoneRow: some View {
        Group {
            if let milestone = snapshot.nextMilestone,
               let remaining = snapshot.daysUntilNextMilestone {
                HStack(spacing: 8) {
                    Text("Prochain palier · \(milestone.title)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                    Spacer(minLength: 8)
                    Text("\(remaining) j")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ProcessStreakPalette.flame)
                        .monospacedDigit()
                }
            } else {
                Text("Tous les paliers sont débloqués.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private func dayFill(for day: ProcessStreakDaySnapshot) -> Color {
        if let verdict = day.verdict {
            switch verdict {
            case .excellent, .onTrack:
                return verdict.chartColor
            case .partial:
                return verdict.chartColor.opacity(0.85)
            case .regression, .missed:
                return verdict.chartColor.opacity(day.isComplete ? 1 : 0.35)
            case .paused:
                return verdict.chartColor.opacity(0.5)
            }
        }
        if day.isComplete {
            return ProcessStreakPalette.flame
        }
        if day.isToday {
            return theme.primaryText.opacity(theme.isDark ? 0.14 : 0.08)
        }
        return theme.primaryText.opacity(theme.isDark ? 0.08 : 0.05)
    }

    private func dayIcon(for day: ProcessStreakDaySnapshot) -> String {
        switch day.verdict {
        case .excellent, .onTrack, .partial:
            return "checkmark"
        case .regression:
            return "exclamationmark"
        case .missed:
            return "minus"
        case .paused:
            return "pause.fill"
        case .none:
            return "checkmark"
        }
    }
}
