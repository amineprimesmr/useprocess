import Foundation

enum ProcessPlanProgressEngine {

    static let maxReductionDays = 21
    static let maxExtensionDays = 21

    // MARK: - Snapshot

    static func snapshot(
        plan: FaceOriginPlan?,
        trajectory: DebloatTrajectorySnapshot,
        adjustmentDays: Int,
        latestEvent: PlanDurationEvolutionEvent?,
        profile: UnifiedUserProfile? = nil,
        now: Date = Date()
    ) -> PlanProgressSnapshot {
        guard let plan else { return .empty }

        let calendar = Calendar.current
        let baseDays = max(7, plan.calendar.totalDays > 0 ? plan.calendar.totalDays : plan.totalWeeks * 7)
        let clampedAdjustment = clampAdjustment(adjustmentDays, baseDays: baseDays)
        let totalDays = max(7, baseDays + clampedAdjustment)

        let startedAt = plan.calendar.startedAt ?? plan.createdAt
        let elapsedIndex = plan.calendar.startedAt != nil
            ? plan.calendar.currentProgramDayIndex(from: now)
            : 0
        let elapsedDays = plan.calendar.startedAt != nil ? elapsedIndex + 1 : 0
        let remaining = max(0, totalDays - elapsedDays)

        let currentWeek = plan.calendar.startedAt != nil
            ? plan.calendar.currentWeekNumber(from: now)
            : 1

        let anchor = calendar.startOfDay(for: plan.calendar.startedAt ?? now)
        let endDate = calendar.date(byAdding: .day, value: totalDays - 1, to: anchor)

        let timeProgress = totalDays > 0 ? min(1, Double(elapsedDays) / Double(totalDays)) : 0
        let validationProgress = totalDays > 0
            ? min(1, Double(trajectory.totalValidatedDays) / Double(totalDays))
            : 0

        let weeksLabel = plan.totalWeeks == 1
            ? "1 semaine"
            : "\(plan.totalWeeks) semaines"

        let milestoneData = buildMilestones(
            plan: plan,
            profile: profile,
            elapsedDays: elapsedDays,
            anchor: anchor,
            calendar: calendar
        )

        let headline: String
        let subtitle: String

        if let active = milestoneData.activeLabel, let activeMilestone = milestoneData.milestones.first(where: { $0.isActive }) {
            if plan.calendar.startedAt == nil {
                if let date = activeMilestone.estimatedDate {
                    headline = "\(active) d'ici \(Self.formatDate(date))"
                } else {
                    headline = "Objectif \(active.lowercased())"
                }
                subtitle = milestoneData.mode.map { "\($0.label) — \(weeksLabel) au total." }
                    ?? "Plan calibré sur ton profil."
            } else {
                headline = "Semaine \(currentWeek) / \(plan.totalWeeks)"
                let remainingWeeks = ProcessDurationFormat.weekCount(fromDays: activeMilestone.remainingDays)
                var parts = ["\(active) : \(ProcessDurationFormat.weeksLabel(count: remainingWeeks)) restante\(remainingWeeks > 1 ? "s" : "")"]
                if let endDate {
                    parts.append("fin totale \(Self.formatDate(endDate))")
                }
                parts.append("\(trajectory.totalValidatedDays) j validé\(trajectory.totalValidatedDays > 1 ? "s" : "")")
                subtitle = parts.joined(separator: " · ")
            }
        } else if plan.calendar.startedAt == nil {
            if let endDate {
                headline = "Objectif d'ici \(Self.formatDate(endDate))"
            } else {
                headline = weeksLabel
            }
            subtitle = "Plan calibré sur ton profil — \(weeksLabel)."
        } else {
            headline = "Semaine \(currentWeek) / \(plan.totalWeeks)"
            let remainingWeeks = ProcessDurationFormat.weekCount(fromDays: remaining)
            var parts = ["\(ProcessDurationFormat.weeksLabel(count: remainingWeeks)) restante\(remainingWeeks > 1 ? "s" : "")"]
            if let endDate {
                parts.append("fin estimée \(Self.formatDate(endDate))")
            }
            parts.append("\(trajectory.totalValidatedDays) j validé\(trajectory.totalValidatedDays > 1 ? "s" : "")")
            subtitle = parts.joined(separator: " · ")
        }

        return PlanProgressSnapshot(
            hasPlan: true,
            totalProgramDays: totalDays,
            baseProgramDays: baseDays,
            durationAdjustmentDays: clampedAdjustment,
            elapsedProgramDays: elapsedDays,
            remainingProgramDays: remaining,
            currentWeek: currentWeek,
            totalWeeks: plan.totalWeeks,
            validatedDays: trajectory.totalValidatedDays,
            currentStreak: trajectory.currentStreak,
            estimatedEndDate: endDate,
            timeProgress: timeProgress,
            validationProgress: validationProgress,
            headline: headline,
            subtitle: subtitle,
            weeksLabel: weeksLabel,
            latestEvolutionNote: latestEvent?.message,
            trajectoryMode: milestoneData.mode,
            milestones: milestoneData.milestones,
            activeMilestoneLabel: milestoneData.activeLabel
        )
    }

    // MARK: - Milestones

    private struct MilestoneData {
        let mode: TrajectoryMode?
        let milestones: [PlanMilestoneProgress]
        let activeLabel: String?
    }

    private static func buildMilestones(
        plan: FaceOriginPlan,
        profile: UnifiedUserProfile?,
        elapsedDays: Int,
        anchor: Date,
        calendar: Calendar
    ) -> MilestoneData {
        guard let assessment = plan.assessmentSnapshot,
              let mode = assessment.trajectoryMode,
              let debloatTarget = assessment.debloatTargetDays else {
            return MilestoneData(mode: nil, milestones: [], activeLabel: nil)
        }

        let weightLabel: String?
        if let ideal = profile?.idealWeight, ideal > 0 {
            weightLabel = "\(Int(ideal.rounded())) kg"
        } else {
            weightLabel = assessment.weightTargetDays != nil ? "Poids cible" : nil
        }

        func makeMilestone(id: String, label: String, targetDays: Int) -> PlanMilestoneProgress {
            let progress = targetDays > 0 ? min(1, Double(elapsedDays) / Double(targetDays)) : 0
            let isComplete = elapsedDays >= targetDays
            let remaining = max(0, targetDays - elapsedDays)
            let date = calendar.date(byAdding: .day, value: max(0, targetDays - 1), to: anchor)
            return PlanMilestoneProgress(
                id: id,
                label: label,
                targetDays: targetDays,
                elapsedDays: min(elapsedDays, targetDays),
                remainingDays: remaining,
                estimatedDate: date,
                progress: progress,
                isComplete: isComplete,
                isActive: false
            )
        }

        var items: [PlanMilestoneProgress] = []

        switch mode {
        case .debloatFirst:
            items.append(makeMilestone(id: "debloat", label: "Debloat", targetDays: debloatTarget))
            if let weightTarget = assessment.weightTargetDays, let label = weightLabel {
                items.append(makeMilestone(id: "weight", label: label, targetDays: weightTarget))
            }
        case .weightFirst:
            if let weightTarget = assessment.weightTargetDays, let label = weightLabel {
                items.append(makeMilestone(id: "weight", label: label, targetDays: weightTarget))
            }
            let debloatEnd = assessment.trajectoryTotalDays
                ?? ((assessment.weightTargetDays ?? 0) + debloatTarget)
            items.append(makeMilestone(id: "debloat", label: "Debloat", targetDays: debloatEnd))
        }

        var resolved = items
        if let firstIncomplete = resolved.firstIndex(where: { !$0.isComplete }) {
            let item = resolved[firstIncomplete]
            resolved[firstIncomplete] = PlanMilestoneProgress(
                id: item.id,
                label: item.label,
                targetDays: item.targetDays,
                elapsedDays: item.elapsedDays,
                remainingDays: item.remainingDays,
                estimatedDate: item.estimatedDate,
                progress: item.progress,
                isComplete: item.isComplete,
                isActive: true
            )
        }

        let activeLabel = resolved.first(where: { $0.isActive })?.label
            ?? resolved.first(where: { !$0.isComplete })?.label
            ?? resolved.last?.label

        return MilestoneData(mode: mode, milestones: resolved, activeLabel: activeLabel)
    }

    // MARK: - Évolution durée

    static func evaluateDurationAdjustment(
        state: ProcessPlanProgressState,
        plan: FaceOriginPlan?,
        trajectory: DebloatTrajectorySnapshot,
        records: [DebloatDayRecord],
        consecutiveMisses: Int,
        earlyCompletion: Bool,
        now: Date = Date()
    ) -> ProcessPlanProgressState {
        guard plan != nil else { return state }

        var updated = state
        var tokens = updated.appliedTokens
        var adjustment = updated.adjustmentDays
        var events = updated.events

        func apply(delta: Int, token: String, reason: PlanDurationEvolutionReason, message: String) {
            guard !tokens.contains(token) else { return }
            let baseDays = max(7, plan?.calendar.totalDays ?? (plan?.totalWeeks ?? 1) * 7)
            let next = clampAdjustment(adjustment + delta, baseDays: baseDays)
            guard next != adjustment else { return }

            adjustment = next
            tokens.insert(token)
            events.insert(
                PlanDurationEvolutionEvent(
                    id: UUID().uuidString,
                    createdAt: now,
                    deltaDays: delta,
                    reason: reason,
                    message: message
                ),
                at: 0
            )
        }

        if earlyCompletion {
            apply(
                delta: -7,
                token: "scan_early_completion",
                reason: .earlyScanCompletion,
                message: "Objectifs atteints en avance — plan raccourci d'une semaine."
            )
        }

        let streakMilestones: [(days: Int, reduction: Int)] = [
            (7, 3),
            (14, 3),
            (30, 7)
        ]
        for milestone in streakMilestones where trajectory.currentStreak >= milestone.days {
            apply(
                delta: -milestone.reduction,
                token: "streak_\(milestone.days)",
                reason: .streakMilestone,
                message: "Série de \(milestone.days) jours — plan accéléré de \(ProcessDurationFormat.weeksShort(fromDays: milestone.reduction))."
            )
        }

        if consecutiveMisses >= 2 {
            apply(
                delta: 7,
                token: "consecutive_misses",
                reason: .consecutiveMisses,
                message: "Jours manqués — plan prolongé d'une semaine pour te laisser le temps de reprendre."
            )
        } else if consecutiveMisses == 0 {
            tokens.remove("consecutive_misses")
        }

        if regressionEpisode(in: records, dayCount: 3) {
            apply(
                delta: 3,
                token: "regression_episode",
                reason: .regressionPattern,
                message: "Régression détectée — plan ajusté (\(ProcessDurationFormat.weeksShort(fromDays: 3))) pour stabiliser ta trajectoire."
            )
        } else {
            tokens.remove("regression_episode")
        }

        updated.adjustmentDays = adjustment
        updated.appliedTokens = tokens
        updated.events = Array(events.prefix(12))
        return updated
    }

    // MARK: - Helpers

    private static func clampAdjustment(_ adjustment: Int, baseDays: Int) -> Int {
        let minAdjustment = -min(maxReductionDays, max(0, baseDays - 7))
        let maxAdjustment = maxExtensionDays
        return min(maxAdjustment, max(minAdjustment, adjustment))
    }

    private static func regressionEpisode(in records: [DebloatDayRecord], dayCount: Int) -> Bool {
        let recent = records
            .sorted { $0.dayKey > $1.dayKey }
            .prefix(dayCount)
        guard recent.count >= 2 else { return false }
        let regressions = recent.filter { $0.verdict == .regression || $0.verdict == .missed }.count
        return regressions >= 2
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
