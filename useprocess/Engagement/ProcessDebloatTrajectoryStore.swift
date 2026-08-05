import Foundation

@MainActor
@Observable
final class ProcessDebloatTrajectoryStore {
    static let shared = ProcessDebloatTrajectoryStore()

    private(set) var snapshot: DebloatTrajectorySnapshot = .empty
    private var state = ProcessDebloatTrajectoryState()
    private var persistenceGeneration: UInt64 = 0

    private init() {
        state = loadState() ?? ProcessDebloatTrajectoryState()
        refreshSnapshot()
    }

    // MARK: - Public

    func reload() {
        state = loadState() ?? ProcessDebloatTrajectoryState()
        migrateLegacyCheckInsIfNeeded()
        migrateFaceScansIfNeeded()
        reconcileWithEveningCheckInStore()
        rebuildAllStreaks()
        refreshSnapshot()
    }

    func recordCheckIn(answers: [String: String], for date: Date = Date()) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayKey = ProcessStreakStore.dayKey(for: dayStart, calendar: calendar)
        let sanitized = sanitizedAnswers(answers)

        let isPaused = ProcessActivityStatusStore.shared.status(for: dayStart) != .active
        let behavior = ProcessDebloatTrajectoryEngine.behaviorScore(from: sanitized)
        let cardioMissesBefore = ProcessDebloatValidation.consecutiveCardioMisses(
            before: dayKey,
            in: state.recordsByDay
        )

        var record = state.recordsByDay[dayKey] ?? emptyRecord(dayKey: dayKey)
        record.checkInSubmitted = true
        record.water = ProcessDebloatTrajectoryEngine.boolAnswer(sanitized, key: EveningCheckInQuestionID.water)
        record.debloatMeal = ProcessDebloatTrajectoryEngine.boolAnswer(sanitized, key: EveningCheckInQuestionID.debloatMeal)
        record.cardio = ProcessDebloatTrajectoryEngine.boolAnswer(sanitized, key: EveningCheckInQuestionID.cardio)
        record.behaviorScore = behavior

        if record.scanScore == nil {
            record.scanScore = ProcessDebloatTrajectoryEngine.rollingScanScore(
                from: Array(state.recordsByDay.values),
                before: dayKey
            )
        }

        record.verdict = ProcessDebloatTrajectoryEngine.verdict(
            record: record,
            consecutiveCardioMissesBefore: cardioMissesBefore,
            scanScore: record.scanScore,
            isPaused: isPaused
        )

        finalizeRecord(&record, dayKey: dayKey)
        state.recordsByDay[dayKey] = record
        persist()
        refreshSnapshot()
        syncPlanProgress(plan: WelcomePlanStore.shared.plan)
        Task { await DebloatTrajectoryFirestoreRepository.shared.saveDay(record) }

        CoachDebloatJourneyStore.appendCheckInEvent(
            answers: sanitized,
            record: record,
            in: CoachConversationLibraryStore.shared
        )
    }

    func recordScan(_ result: FaceScanResult, for date: Date? = nil) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date ?? result.createdAt)
        let dayKey = ProcessStreakStore.dayKey(for: dayStart, calendar: calendar)

        let scan = ProcessDebloatTrajectoryEngine.scanScore(
            relativeFaceScore: result.relativeFaceDayScore ?? result.displayWellnessScore,
            puffinessDelta: result.relativeSignals?.puffinessDelta
        )

        var record = state.recordsByDay[dayKey] ?? emptyRecord(dayKey: dayKey)
        record.scanId = result.id
        record.relativeFaceScore = result.relativeFaceDayScore ?? result.displayWellnessScore
        record.puffinessDelta = result.relativeSignals?.puffinessDelta
        record.scanScore = scan

        if record.checkInSubmitted {
            let cardioMissesBefore = ProcessDebloatValidation.consecutiveCardioMisses(
                before: dayKey,
                in: state.recordsByDay
            )
            record.verdict = ProcessDebloatTrajectoryEngine.verdict(
                record: record,
                consecutiveCardioMissesBefore: cardioMissesBefore,
                scanScore: scan,
                isPaused: record.verdict == .paused
            )
            finalizeRecord(&record, dayKey: dayKey, recomputeStreak: false)
        } else {
            record.compositeScore = ProcessDebloatTrajectoryEngine.compositeScore(
                behaviorScore: record.behaviorScore,
                scanScore: scan,
                momentumStreak: previousStreak(before: dayKey)
            )
            record.aiSummary = scanSummary(puffinessDelta: record.puffinessDelta)
        }

        state.recordsByDay[dayKey] = record
        persist()
        refreshSnapshot()
        Task { await DebloatTrajectoryFirestoreRepository.shared.saveDay(record) }
    }

    func record(for dayKey: String) -> DebloatDayRecord? {
        state.recordsByDay[dayKey]
    }

    func record(for date: Date) -> DebloatDayRecord? {
        let key = ProcessStreakStore.dayKey(for: date)
        return state.recordsByDay[key]
    }

    func recentRecords(limit: Int = 14) -> [DebloatDayRecord] {
        state.recordsByDay.values
            .sorted { $0.dayKey > $1.dayKey }
            .prefix(limit)
            .map { $0 }
    }

    var allRecordsByDay: [String: DebloatDayRecord] {
        state.recordsByDay
    }

    var consecutiveMissCount: Int {
        state.consecutiveMisses
    }

    var consecutiveCardioMissCount: Int {
        state.consecutiveCardioMisses
    }

    func chartPoints(dayCount: Int = 30) -> [DebloatTrajectoryPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<dayCount).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = ProcessStreakStore.dayKey(for: date, calendar: calendar)
            guard let record = state.recordsByDay[key] else { return nil }
            return DebloatTrajectoryPoint(
                id: key,
                date: date,
                compositeScore: record.compositeScore,
                verdict: record.verdict,
                hasScan: record.hasScan
            )
        }
    }

    var debloatJourneyConversationId: UUID? {
        state.debloatJourneyConversationId.flatMap(UUID.init(uuidString:))
    }

    func setDebloatJourneyConversationId(_ id: UUID) {
        state.debloatJourneyConversationId = id.uuidString
        persist()
    }

    func sync(from plan: FaceOriginPlan?) {
        migrateFaceScansIfNeeded()
        reconcileWithEveningCheckInStore()
        purgeInvalidMissedRecords(plan: plan)
        reconcileMissedDays(plan: plan)
        rebuildAllStreaks()
        refreshSnapshot()
        syncPlanProgress(plan: plan)
    }

    // MARK: - Missed days

    func reconcileMissedDays(now: Date = Date(), plan: FaceOriginPlan? = nil) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }
        let yesterdayKey = ProcessStreakStore.dayKey(for: yesterday, calendar: calendar)

        if let startedAt = plan?.calendar.startedAt {
            let programStart = calendar.startOfDay(for: startedAt)
            if yesterday < programStart { return }
        }

        guard state.recordsByDay.values.contains(where: { $0.checkInSubmitted }) else { return }
        guard state.recordsByDay[yesterdayKey] == nil else { return }

        let isPaused = ProcessActivityStatusStore.shared.status(for: yesterday) != .active
        var record = emptyRecord(dayKey: yesterdayKey)
        record.verdict = isPaused ? .paused : .missed
        finalizeRecord(&record, dayKey: yesterdayKey)
        state.recordsByDay[yesterdayKey] = record
        rebuildAllStreaks()
        persist()
    }

    private func purgeInvalidMissedRecords(plan: FaceOriginPlan?) {
        guard let startedAt = plan?.calendar.startedAt else { return }
        let calendar = Calendar.current
        let programStart = calendar.startOfDay(for: startedAt)
        var changed = false

        for (key, record) in state.recordsByDay {
            guard record.verdict == .missed, !record.checkInSubmitted else { continue }
            guard let date = ProcessDebloatTrajectoryEngine.date(from: key) else { continue }
            guard date < programStart else { continue }
            state.recordsByDay.removeValue(forKey: key)
            changed = true
        }

        if changed {
            rebuildAllStreaks()
            persist()
        }
    }

    // MARK: - Private record building

    private func emptyRecord(dayKey: String) -> DebloatDayRecord {
        DebloatDayRecord(
            dayKey: dayKey,
            checkInSubmitted: false,
            water: nil,
            debloatMeal: nil,
            cardio: nil,
            behaviorScore: 0,
            scanId: nil,
            relativeFaceScore: nil,
            puffinessDelta: nil,
            scanScore: nil,
            compositeScore: 0,
            verdict: .pending,
            streakAfterDay: 0,
            graceUsed: false,
            aiSummary: nil,
            trajectoryTrend: .unknown
        )
    }

    private func finalizeRecord(
        _ record: inout DebloatDayRecord,
        dayKey: String,
        recomputeStreak: Bool = true
    ) {
        let previous = previousStreak(before: dayKey)
        let grace = ProcessDebloatTrajectoryEngine.graceAvailable(
            graceUsedDayKeys: state.graceUsedDayKeys,
            for: dayKey
        )

        let transition = ProcessDebloatTrajectoryEngine.applyStreakTransition(
            previousStreak: previous,
            consecutiveMisses: state.consecutiveMisses,
            verdict: record.verdict,
            graceAvailable: grace
        )

        record.streakAfterDay = transition.streak
        record.graceUsed = transition.graceUsed
        if transition.graceUsed {
            state.graceUsedDayKeys.insert(dayKey)
        }
        state.consecutiveMisses = transition.consecutiveMisses
        state.longestStreak = max(state.longestStreak, transition.streak)

        record.compositeScore = ProcessDebloatTrajectoryEngine.compositeScore(
            behaviorScore: record.behaviorScore,
            scanScore: record.scanScore,
            momentumStreak: transition.streak
        )

        let points = chartPoints(dayCount: 14)
        record.trajectoryTrend = ProcessDebloatTrajectoryEngine.trajectoryTrend(for: points)

        record.aiSummary = ProcessDebloatTrajectoryEngine.aiSummary(
            record: record,
            consecutiveCardioMissesBefore: ProcessDebloatValidation.consecutiveCardioMisses(
                before: dayKey,
                in: state.recordsByDay
            ),
            compositeScore: record.compositeScore,
            puffinessDelta: record.puffinessDelta
        )

        if recomputeStreak {
            rebuildAllStreaks()
        }
    }

    private func rebuildAllStreaks(now: Date = Date()) {
        let sorted = state.recordsByDay.keys.sorted()
        var consecutiveMisses = 0
        var consecutiveCardioMisses = 0
        var graceKeys = Set<String>()
        var longest = 0

        for (index, key) in sorted.enumerated() {
            guard var record = state.recordsByDay[key] else { continue }
            let previous = index > 0 ? (state.recordsByDay[sorted[index - 1]]?.streakAfterDay ?? 0) : 0
            let grace = ProcessDebloatTrajectoryEngine.graceAvailable(
                graceUsedDayKeys: graceKeys,
                for: key
            )

            if record.checkInSubmitted {
                record.verdict = ProcessDebloatTrajectoryEngine.verdict(
                    record: record,
                    consecutiveCardioMissesBefore: consecutiveCardioMisses,
                    scanScore: record.scanScore,
                    isPaused: record.verdict == .paused,
                    now: now
                )
            } else {
                let isPaused = ProcessActivityStatusStore.shared.status(
                    for: ProcessDebloatTrajectoryEngine.date(from: key) ?? now
                ) != .active
                record.verdict = isPaused
                    ? .paused
                    : ProcessDebloatTrajectoryEngine.unsubmittedVerdict(for: key, now: now)
            }

            let transition = ProcessDebloatTrajectoryEngine.applyStreakTransition(
                previousStreak: previous,
                consecutiveMisses: consecutiveMisses,
                verdict: record.verdict,
                graceAvailable: grace
            )

            record.streakAfterDay = transition.streak
            record.graceUsed = transition.graceUsed
            if transition.graceUsed {
                graceKeys.insert(key)
            }
            consecutiveMisses = transition.consecutiveMisses
            longest = max(longest, transition.streak)

            record.compositeScore = ProcessDebloatTrajectoryEngine.compositeScore(
                behaviorScore: record.behaviorScore,
                scanScore: record.scanScore,
                momentumStreak: transition.streak
            )
            record.aiSummary = ProcessDebloatTrajectoryEngine.aiSummary(
                record: record,
                consecutiveCardioMissesBefore: consecutiveCardioMisses,
                compositeScore: record.compositeScore,
                puffinessDelta: record.puffinessDelta
            )

            consecutiveCardioMisses = ProcessDebloatTrajectoryEngine.applyCardioMissTransition(
                previousMisses: consecutiveCardioMisses,
                record: record
            )

            state.recordsByDay[key] = record
        }

        state.graceUsedDayKeys = graceKeys
        state.consecutiveMisses = consecutiveMisses
        state.consecutiveCardioMisses = consecutiveCardioMisses
        state.longestStreak = max(state.longestStreak, longest)
    }

    private func isValidatedDay(_ record: DebloatDayRecord) -> Bool {
        let cardioBefore = ProcessDebloatValidation.consecutiveCardioMisses(
            before: record.dayKey,
            in: state.recordsByDay
        )
        return record.countsAsValidatedDay(consecutiveCardioMissesBefore: cardioBefore)
    }

    private func previousStreak(before dayKey: String) -> Int {
        let sorted = state.recordsByDay.keys.sorted()
        guard let index = sorted.firstIndex(of: dayKey), index > 0 else {
            if let prevKey = sorted.last(where: { $0 < dayKey }),
               let prev = state.recordsByDay[prevKey] {
                return prev.streakAfterDay
            }
            return 0
        }
        let prevKey = sorted[index - 1]
        return state.recordsByDay[prevKey]?.streakAfterDay ?? 0
    }

    private func scanSummary(puffinessDelta: Int?) -> String {
        guard let delta = puffinessDelta else {
            return AppCopy.t(
                "Scan enregistré — fais ton check pour compléter la trajectoire.",
                en: "Scan saved — complete your check-in to finish the trajectory."
            )
        }
        if delta <= -4 {
            return AppCopy.t(
                "Scan : moins gonflé qu'à l'habitude.",
                en: "Scan: less puffy than usual."
            )
        }
        if delta >= 6 {
            return AppCopy.t(
                "Scan : rétention en hausse — eau régulière, sodium modéré, potassium alimentaire.",
                en: "Scan: retention up — steady water, moderate sodium, dietary potassium."
            )
        }
        return AppCopy.t(
            "Scan : signaux stables vs ta baseline.",
            en: "Scan: signals stable vs your baseline."
        )
    }

    // MARK: - Snapshot

    private func refreshSnapshot(now: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let todayKey = ProcessStreakStore.dayKey(for: today, calendar: calendar)
        let todayRecord = state.recordsByDay[todayKey]

        let chartPoints = chartPoints(dayCount: 30)
        let current = ProcessDebloatTrajectoryEngine.currentStreak(
            from: Array(state.recordsByDay.values),
            today: today,
            calendar: calendar
        )

        let streakEligibleKeys = Set(
            state.recordsByDay.values
                .filter { isValidatedDay($0) }
                .map(\.dayKey)
        )

        let calendarWeek = ProcessStreakStore.buildCalendarWeekSnapshots(
            completedKeys: streakEligibleKeys,
            recordsByDay: state.recordsByDay,
            now: now,
            calendar: calendar
        )

        let todayProgress: Double
        if let record = todayRecord, record.checkInSubmitted {
            todayProgress = record.behaviorScore
        } else {
            todayProgress = 0
        }

        let nextMilestone = ProcessStreakMilestone.catalog.first(where: { $0.days > current })
        let daysUntil = nextMilestone.map { $0.days - current }

        let todayCardioBefore = ProcessDebloatValidation.consecutiveCardioMisses(
            before: todayKey,
            in: state.recordsByDay
        )
        let isTodayValidated = todayRecord?.countsAsValidatedDay(
            consecutiveCardioMissesBefore: todayCardioBefore
        ) == true

        let updated = DebloatTrajectorySnapshot(
            currentStreak: current,
            longestStreak: max(state.longestStreak, current),
            todayCompositeScore: todayRecord?.compositeScore ?? 0,
            todayVerdict: todayRecord?.verdict,
            todayProgress: todayProgress,
            isTodayComplete: isTodayValidated,
            trajectoryTrend: ProcessDebloatTrajectoryEngine.trajectoryTrend(for: chartPoints),
            velocitySlope: ProcessDebloatTrajectoryEngine.velocitySlope(for: chartPoints),
            chartPoints: chartPoints,
            calendarWeek: calendarWeek,
            nextMilestone: nextMilestone,
            daysUntilNextMilestone: daysUntil,
            totalValidatedDays: state.recordsByDay.values.filter { isValidatedDay($0) }.count
        )

        if snapshot != updated {
            snapshot = updated
        }

        ProcessStreakStore.shared.applyTrajectorySnapshot(
            updated,
            eligibleKeys: streakEligibleKeys,
            recordsByDay: state.recordsByDay
        )
    }

    private func syncPlanProgress(plan: FaceOriginPlan?) {
        ProcessPlanProgressStore.shared.sync(
            plan: plan,
            trajectory: snapshot,
            records: Array(state.recordsByDay.values),
            consecutiveMisses: state.consecutiveMisses,
            consecutiveCardioMisses: state.consecutiveCardioMisses
        )
    }

    // MARK: - Migration

    private func reconcileWithEveningCheckInStore(now: Date = Date()) {
        let evening = ProcessEveningCheckInStore.shared
        var changed = false

        for key in Array(state.recordsByDay.keys) {
            guard var record = state.recordsByDay[key] else { continue }
            let submitted = evening.submittedDayKeys.contains(key)

            if submitted {
                guard let date = ProcessDebloatTrajectoryEngine.date(from: key) else { continue }
                let answers = evening.answers(for: date)
                record.checkInSubmitted = true
                record.water = ProcessDebloatTrajectoryEngine.boolAnswer(answers, key: EveningCheckInQuestionID.water)
                record.debloatMeal = ProcessDebloatTrajectoryEngine.boolAnswer(answers, key: EveningCheckInQuestionID.debloatMeal)
                record.cardio = ProcessDebloatTrajectoryEngine.boolAnswer(answers, key: EveningCheckInQuestionID.cardio)
                record.behaviorScore = ProcessDebloatTrajectoryEngine.behaviorScore(from: answers)
                state.recordsByDay[key] = record
                changed = true
            } else if record.checkInSubmitted {
                record.checkInSubmitted = false
                record.water = nil
                record.debloatMeal = nil
                record.cardio = nil
                record.behaviorScore = 0
                let isPaused = ProcessActivityStatusStore.shared.status(
                    for: ProcessDebloatTrajectoryEngine.date(from: key) ?? now
                ) != .active
                record.verdict = isPaused
                    ? .paused
                    : ProcessDebloatTrajectoryEngine.unsubmittedVerdict(for: key, now: now)
                record.graceUsed = false
                record.streakAfterDay = 0
                state.recordsByDay[key] = record
                changed = true
            }
        }

        if changed {
            state.graceUsedDayKeys = []
        }
    }

    private func migrateLegacyCheckInsIfNeeded() {
        let evening = ProcessEveningCheckInStore.shared
        guard !evening.submittedDayKeys.isEmpty else { return }

        var changed = false
        for dayKey in evening.submittedDayKeys {
            guard state.recordsByDay[dayKey] == nil else { continue }
            guard let date = ProcessDebloatTrajectoryEngine.date(from: dayKey) else { continue }

            let answers = evening.answers(for: date)
            let behavior = ProcessDebloatTrajectoryEngine.behaviorScore(from: answers)
            let isPaused = ProcessActivityStatusStore.shared.status(for: date) != .active

            var record = emptyRecord(dayKey: dayKey)
            record.checkInSubmitted = true
            record.water = ProcessDebloatTrajectoryEngine.boolAnswer(answers, key: EveningCheckInQuestionID.water)
            record.debloatMeal = ProcessDebloatTrajectoryEngine.boolAnswer(answers, key: EveningCheckInQuestionID.debloatMeal)
            record.cardio = ProcessDebloatTrajectoryEngine.boolAnswer(answers, key: EveningCheckInQuestionID.cardio)
            record.behaviorScore = behavior
            record.scanScore = ProcessDebloatTrajectoryEngine.rollingScanScore(
                from: Array(state.recordsByDay.values),
                before: dayKey
            )
            let cardioMissesBefore = ProcessDebloatValidation.consecutiveCardioMisses(
                before: dayKey,
                in: state.recordsByDay
            )
            record.verdict = ProcessDebloatTrajectoryEngine.verdict(
                record: record,
                consecutiveCardioMissesBefore: cardioMissesBefore,
                scanScore: record.scanScore,
                isPaused: isPaused
            )
            finalizeRecord(&record, dayKey: dayKey, recomputeStreak: false)
            state.recordsByDay[dayKey] = record
            changed = true
        }

        if changed {
            rebuildAllStreaks()
            persist()
        }
    }

    private func migrateFaceScansIfNeeded() {
        let scans = FaceScanHistoryStore.shared.history
        guard !scans.isEmpty else { return }

        let needsMigration = scans.contains { scan in
            let dayKey = ProcessStreakStore.dayKey(for: scan.createdAt)
            if let existing = state.recordsByDay[dayKey], existing.scanId != nil {
                return false
            }
            return true
        }
        guard needsMigration else { return }

        var changed = false
        for scan in scans {
            let dayKey = ProcessStreakStore.dayKey(for: scan.createdAt)
            if let existing = state.recordsByDay[dayKey], existing.scanId != nil {
                continue
            }
            recordScan(scan, for: scan.createdAt)
            changed = true
        }

        if changed {
            refreshSnapshot()
        }
    }

    private func sanitizedAnswers(_ answers: [String: String]) -> [String: String] {
        var normalized = Dictionary(
            uniqueKeysWithValues: answers.filter { EveningCheckInQuestionID.all.contains($0.key) }
        )
        if normalized[EveningCheckInQuestionID.cardio] == nil,
           let legacy = answers[EveningCheckInQuestionID.legacyPostureCircuit] {
            normalized[EveningCheckInQuestionID.cardio] = legacy
        }
        return normalized
    }

    // MARK: - Persistence

    private func persist() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.debloat.trajectory", userId: uid)
        let stateSnapshot = state
        persistenceGeneration &+= 1
        let generation = persistenceGeneration
        Task.detached(priority: .utility) {
            await ProcessPersistenceWriter.shared.store(
                stateSnapshot,
                forKey: key,
                generation: generation
            )
        }
    }

    private func loadState() -> ProcessDebloatTrajectoryState? {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.debloat.trajectory", userId: uid)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ProcessDebloatTrajectoryState.self, from: data)
    }
}
