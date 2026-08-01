import Foundation

enum ProcessPlanProgressEngine {

    static let maxReductionDays = 21
    static let maxExtensionDays = 21

    /// Durée canonique = promesse debloat onboarding (`debloatTargetDays`).
    /// Le programme se termine quand le debloat est atteint à 100 %.
    static func canonicalBaseProgramDays(plan: FaceOriginPlan) -> Int {
        if let debloat = plan.assessmentSnapshot?.debloatTargetDays, debloat > 0 {
            return debloat
        }
        if let trajectory = plan.assessmentSnapshot?.trajectoryTotalDays, trajectory > 0 {
            return trajectory
        }
        let calendarDays = plan.calendar.totalDays
        if calendarDays > 0 { return calendarDays }
        return max(7, plan.totalWeeks * 7)
    }

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
        let baseDays = max(7, canonicalBaseProgramDays(plan: plan))
        let clampedAdjustment = clampAdjustment(adjustmentDays, baseDays: baseDays)
        let totalDays = max(7, baseDays + clampedAdjustment)

        let elapsedIndex = plan.calendar.startedAt != nil
            ? plan.calendar.currentProgramDayIndex(from: now)
            : 0
        let elapsedDays = plan.calendar.startedAt != nil ? elapsedIndex + 1 : 0
        let remaining = max(0, totalDays - elapsedDays)

        let anchor = calendar.startOfDay(for: plan.calendar.startedAt ?? now)
        let endDate = calendar.date(byAdding: .day, value: totalDays - 1, to: anchor)

        let timeProgress = totalDays > 0 ? min(1, Double(elapsedDays) / Double(totalDays)) : 0
        let validationProgress = totalDays > 0
            ? min(1, Double(trajectory.totalValidatedDays) / Double(totalDays))
            : 0

        let daysLabel = totalDays == 1 ? "1 jour" : "\(totalDays) jours"
        let isComplete = elapsedDays >= totalDays

        let headline: String
        let subtitle: String

        if plan.calendar.startedAt == nil {
            headline = "Programme debloat · \(daysLabel)"
            if let endDate {
                subtitle = "Debloat visé le \(Self.formatDate(endDate))"
            } else {
                subtitle = "Calibré sur ton profil onboarding."
            }
        } else if isComplete {
            headline = "Programme debloat terminé"
            subtitle = "\(trajectory.totalValidatedDays) jour\(trajectory.totalValidatedDays > 1 ? "s" : "") validé\(trajectory.totalValidatedDays > 1 ? "s" : "")"
        } else {
            headline = "Jour \(elapsedDays) / \(totalDays)"
            var parts: [String] = []
            if remaining > 0 {
                parts.append("\(remaining) j restant\(remaining > 1 ? "s" : "")")
            }
            if let endDate {
                parts.append("debloat le \(Self.formatDate(endDate))")
            }
            if trajectory.totalValidatedDays > 0 {
                parts.append("\(trajectory.totalValidatedDays) j validé\(trajectory.totalValidatedDays > 1 ? "s" : "")")
            }
            subtitle = parts.joined(separator: " · ")
        }

        return PlanProgressSnapshot(
            hasPlan: true,
            totalProgramDays: totalDays,
            baseProgramDays: baseDays,
            durationAdjustmentDays: clampedAdjustment,
            elapsedProgramDays: elapsedDays,
            remainingProgramDays: remaining,
            currentWeek: 0,
            totalWeeks: 0,
            validatedDays: trajectory.totalValidatedDays,
            currentStreak: trajectory.currentStreak,
            estimatedEndDate: endDate,
            timeProgress: timeProgress,
            validationProgress: validationProgress,
            headline: headline,
            subtitle: subtitle,
            weeksLabel: daysLabel,
            latestEvolutionNote: latestEvent.map { sanitizeEvolutionMessage($0) },
            trajectoryMode: nil,
            milestones: [],
            activeMilestoneLabel: isComplete ? nil : "Debloat",
            debloatTargetDays: baseDays,
            debloatEstimatedDate: endDate,
            debloatRemainingDays: remaining
        )
    }

    // MARK: - Évolution durée

    static func evaluateDurationAdjustment(
        state: ProcessPlanProgressState,
        plan: FaceOriginPlan?,
        trajectory: DebloatTrajectorySnapshot,
        records: [DebloatDayRecord],
        consecutiveMisses: Int,
        consecutiveCardioMisses: Int = 0,
        earlyCompletion: Bool = false,
        now: Date = Date()
    ) -> ProcessPlanProgressState {
        guard plan != nil else { return state }

        var updated = state
        var tokens = updated.appliedTokens
        var adjustment = updated.adjustmentDays
        var events = updated.events

        func apply(delta: Int, token: String, reason: PlanDurationEvolutionReason, message: String) {
            guard !tokens.contains(token) else { return }
            let baseDays = max(7, plan.map { canonicalBaseProgramDays(plan: $0) } ?? 7)
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
                message: evolutionMessage(for: .earlyScanCompletion, deltaDays: -7)
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
                message: evolutionMessage(for: .streakMilestone, deltaDays: -milestone.reduction, streakDays: milestone.days)
            )
        }

        // Prolongation uniquement après 2 bilans manqués d'affilée (sans grâce).
        // Un seul jour oublié ne doit pas rallonger le programme.
        if consecutiveMisses >= 2 {
            apply(
                delta: 3,
                token: "consecutive_misses",
                reason: .consecutiveMisses,
                message: evolutionMessage(for: .consecutiveMisses, deltaDays: 3)
            )
        } else {
            tokens.remove("consecutive_misses")
            let baseDays = max(7, plan.map { canonicalBaseProgramDays(plan: $0) } ?? 7)
            reconcileLegacyRegressionExtension(adjustment: &adjustment, tokens: &tokens, baseDays: baseDays)
        }

        if consecutiveCardioMisses >= ProcessDebloatValidation.consecutiveCardioMissLimit {
            apply(
                delta: 2,
                token: "cardio_consecutive_misses",
                reason: .cardioConsecutiveMisses,
                message: evolutionMessage(for: .cardioConsecutiveMisses, deltaDays: 2)
            )
        } else {
            tokens.remove("cardio_consecutive_misses")
        }

        if let latestKey = records.map(\.dayKey).max(),
           ProcessDebloatValidation.isWeeklyCardioDeficit(
            endingAt: latestKey,
            in: Dictionary(uniqueKeysWithValues: records.map { ($0.dayKey, $0) })
           ) {
            let sessions = ProcessDebloatValidation.cardioSessionsInRollingWindow(
                endingAt: latestKey,
                in: Dictionary(uniqueKeysWithValues: records.map { ($0.dayKey, $0) })
            )
            apply(
                delta: 2,
                token: "cardio_weekly_deficit",
                reason: .cardioWeeklyDeficit,
                message: evolutionMessage(
                    for: .cardioWeeklyDeficit,
                    deltaDays: 2,
                    cardioSessions: sessions
                )
            )
        } else {
            tokens.remove("cardio_weekly_deficit")
        }

        updated.adjustmentDays = adjustment
        updated.appliedTokens = tokens
        updated.events = Array(events.prefix(12)).map { sanitizeEvent($0) }
        return updated
    }

    // MARK: - Migration messages legacy

    static func sanitizeState(_ state: ProcessPlanProgressState) -> ProcessPlanProgressState {
        var updated = state
        updated.events = state.events.map { sanitizeEvent($0) }
        if updated.schemaVersion < 2 {
            updated.schemaVersion = 2
        }
        return updated
    }

    static func sanitizeEvent(_ event: PlanDurationEvolutionEvent) -> PlanDurationEvolutionEvent {
        PlanDurationEvolutionEvent(
            id: event.id,
            createdAt: event.createdAt,
            deltaDays: event.deltaDays,
            reason: event.reason,
            message: sanitizeEvolutionMessage(event)
        )
    }

    static func sanitizeEvolutionMessage(_ event: PlanDurationEvolutionEvent) -> String {
        let lower = event.message.lowercased()
        if lower.contains("sem.") || lower.contains("semaine") {
            return evolutionMessage(for: event.reason, deltaDays: event.deltaDays)
        }
        return event.message
    }

    static func evolutionMessage(
        for reason: PlanDurationEvolutionReason,
        deltaDays: Int,
        streakDays: Int? = nil,
        cardioSessions: Int? = nil
    ) -> String {
        let days = abs(deltaDays)
        switch reason {
        case .earlyScanCompletion:
            return "Objectifs atteints en avance — programme raccourci de \(days) jours."
        case .streakMilestone:
            let streak = streakDays ?? days
            return "\(streak) jours validés — programme accéléré de \(days) jours."
        case .consecutiveMisses:
            return "Bilans manqués — programme prolongé de \(days) jours."
        case .cardioConsecutiveMisses:
            return "Cardio absent 3 jours d'affilée — programme prolongé de \(days) jours."
        case .cardioWeeklyDeficit:
            let count = cardioSessions ?? 0
            return "Cardio insuffisant (\(count)/\(ProcessDebloatValidation.weeklyCardioMinimum) cette semaine) — +\(days) jours."
        case .regressionPattern:
            return "Régression détectée — programme prolongé de \(days) jours."
        }
    }

    // MARK: - Helpers

    private static func clampAdjustment(_ adjustment: Int, baseDays: Int) -> Int {
        let minAdjustment = -min(maxReductionDays, max(0, baseDays - 7))
        let maxAdjustment = maxExtensionDays
        return min(maxAdjustment, max(minAdjustment, adjustment))
    }

    /// Retire l'extension +3 jours legacy déclenchée par une régression + un jour manqué.
    private static func reconcileLegacyRegressionExtension(
        adjustment: inout Int,
        tokens: inout Set<String>,
        baseDays: Int
    ) {
        guard tokens.contains("regression_episode") else { return }
        tokens.remove("regression_episode")
        adjustment = clampAdjustment(adjustment - 3, baseDays: baseDays)
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
}
