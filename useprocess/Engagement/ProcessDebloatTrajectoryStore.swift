import Foundation

@MainActor
@Observable
final class ProcessDebloatTrajectoryStore {
    static let shared = ProcessDebloatTrajectoryStore()

    private(set) var snapshot: DebloatTrajectorySnapshot = .empty
    private var state = ProcessDebloatTrajectoryState()

    private init() {
        state = loadState() ?? ProcessDebloatTrajectoryState()
        refreshSnapshot()
    }

    // MARK: - Public

    func reload() {
        state = loadState() ?? ProcessDebloatTrajectoryState()
        migrateLegacyCheckInsIfNeeded()
        migrateFaceScansIfNeeded()
        reconcileMissedDays()
        refreshSnapshot()
    }

    func recordCheckIn(answers: [String: String], for date: Date = Date()) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayKey = ProcessStreakStore.dayKey(for: dayStart, calendar: calendar)
        let sanitized = sanitizedAnswers(answers)

        let isPaused = ProcessActivityStatusStore.shared.status(for: dayStart) != .active
        let behavior = ProcessDebloatTrajectoryEngine.behaviorScore(from: sanitized)
        let yesCount = ProcessDebloatTrajectoryEngine.yesCount(from: sanitized)

        var record = state.recordsByDay[dayKey] ?? emptyRecord(dayKey: dayKey)
        record.checkInSubmitted = true
        record.water = ProcessDebloatTrajectoryEngine.boolAnswer(sanitized, key: EveningCheckInQuestionID.water)
        record.debloatMeal = ProcessDebloatTrajectoryEngine.boolAnswer(sanitized, key: EveningCheckInQuestionID.debloatMeal)
        record.postureCircuit = ProcessDebloatTrajectoryEngine.boolAnswer(sanitized, key: EveningCheckInQuestionID.postureCircuit)
        record.behaviorScore = behavior

        if record.scanScore == nil {
            record.scanScore = ProcessDebloatTrajectoryEngine.rollingScanScore(
                from: Array(state.recordsByDay.values),
                before: dayKey
            )
        }

        record.verdict = ProcessDebloatTrajectoryEngine.verdict(
            behaviorScore: behavior,
            yesCount: yesCount,
            scanScore: record.scanScore,
            isPaused: isPaused,
            checkInSubmitted: true
        )

        finalizeRecord(&record, dayKey: dayKey)
        state.recordsByDay[dayKey] = record
        persist()
        refreshSnapshot()
        Task { await DebloatTrajectoryFirestoreRepository.shared.saveDay(record) }

        CoachDebloatJourneyStore.appendCheckInEvent(
            answers: sanitized,
            record: record
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
            let yesCount = record.yesCount
            record.verdict = ProcessDebloatTrajectoryEngine.verdict(
                behaviorScore: record.behaviorScore,
                yesCount: yesCount,
                scanScore: scan,
                isPaused: record.verdict == .paused,
                checkInSubmitted: true
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
        reconcileMissedDays()
        refreshSnapshot()
        syncPlanProgress(plan: plan)
    }

    // MARK: - Missed days

    func reconcileMissedDays(now: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }
        let yesterdayKey = ProcessStreakStore.dayKey(for: yesterday, calendar: calendar)

        guard !state.recordsByDay.isEmpty else { return }
        guard state.recordsByDay[yesterdayKey] == nil else { return }

        let isPaused = ProcessActivityStatusStore.shared.status(for: yesterday) != .active
        var record = emptyRecord(dayKey: yesterdayKey)
        record.verdict = isPaused ? .paused : .missed
        finalizeRecord(&record, dayKey: yesterdayKey)
        state.recordsByDay[yesterdayKey] = record
        rebuildAllStreaks()
        persist()
    }

    // MARK: - Private record building

    private func emptyRecord(dayKey: String) -> DebloatDayRecord {
        DebloatDayRecord(
            dayKey: dayKey,
            checkInSubmitted: false,
            water: nil,
            debloatMeal: nil,
            postureCircuit: nil,
            behaviorScore: 0,
            scanId: nil,
            relativeFaceScore: nil,
            puffinessDelta: nil,
            scanScore: nil,
            compositeScore: 0,
            verdict: .missed,
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
            verdict: record.verdict,
            yesCount: record.yesCount,
            compositeScore: record.compositeScore,
            puffinessDelta: record.puffinessDelta
        )

        if recomputeStreak {
            rebuildAllStreaks()
        }
    }

    private func rebuildAllStreaks() {
        let sorted = state.recordsByDay.keys.sorted()
        var consecutiveMisses = 0
        var graceKeys = Set<String>()
        var longest = 0

        for (index, key) in sorted.enumerated() {
            guard var record = state.recordsByDay[key] else { continue }
            let previous = index > 0 ? (state.recordsByDay[sorted[index - 1]]?.streakAfterDay ?? 0) : 0
            let grace = ProcessDebloatTrajectoryEngine.graceAvailable(
                graceUsedDayKeys: graceKeys,
                for: key
            )

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
                verdict: record.verdict,
                yesCount: record.yesCount,
                compositeScore: record.compositeScore,
                puffinessDelta: record.puffinessDelta
            )

            state.recordsByDay[key] = record
        }

        state.graceUsedDayKeys = graceKeys
        state.consecutiveMisses = consecutiveMisses
        state.longestStreak = max(state.longestStreak, longest)
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
            return "Scan enregistré — bilan du soir pour compléter la trajectoire."
        }
        if delta <= -4 { return "Scan : moins gonflé qu'à l'habitude." }
        if delta >= 6 { return "Scan : rétention en hausse — eau régulière, sodium modéré, potassium alimentaire." }
        return "Scan : signaux stables vs ta baseline."
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
                .filter { $0.verdict.countsForStreak || ($0.verdict == .missed && $0.graceUsed) }
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

        let updated = DebloatTrajectorySnapshot(
            currentStreak: current,
            longestStreak: max(state.longestStreak, current),
            todayCompositeScore: todayRecord?.compositeScore ?? 0,
            todayVerdict: todayRecord?.verdict,
            todayProgress: todayProgress,
            isTodayComplete: todayRecord?.checkInSubmitted == true,
            trajectoryTrend: ProcessDebloatTrajectoryEngine.trajectoryTrend(for: chartPoints),
            velocitySlope: ProcessDebloatTrajectoryEngine.velocitySlope(for: chartPoints),
            chartPoints: chartPoints,
            calendarWeek: calendarWeek,
            nextMilestone: nextMilestone,
            daysUntilNextMilestone: daysUntil,
            totalValidatedDays: state.recordsByDay.values.filter(\.checkInSubmitted).count
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
            consecutiveMisses: state.consecutiveMisses
        )
    }

    // MARK: - Migration

    private func migrateLegacyCheckInsIfNeeded() {
        let evening = ProcessEveningCheckInStore.shared
        guard !evening.submittedDayKeys.isEmpty else { return }

        var changed = false
        for dayKey in evening.submittedDayKeys {
            guard state.recordsByDay[dayKey] == nil else { continue }
            guard let date = ProcessDebloatTrajectoryEngine.date(from: dayKey) else { continue }

            let answers = evening.answers(for: date)
            let behavior = ProcessDebloatTrajectoryEngine.behaviorScore(from: answers)
            let yesCount = ProcessDebloatTrajectoryEngine.yesCount(from: answers)
            let isPaused = ProcessActivityStatusStore.shared.status(for: date) != .active

            var record = emptyRecord(dayKey: dayKey)
            record.checkInSubmitted = true
            record.water = ProcessDebloatTrajectoryEngine.boolAnswer(answers, key: EveningCheckInQuestionID.water)
            record.debloatMeal = ProcessDebloatTrajectoryEngine.boolAnswer(answers, key: EveningCheckInQuestionID.debloatMeal)
            record.postureCircuit = ProcessDebloatTrajectoryEngine.boolAnswer(answers, key: EveningCheckInQuestionID.postureCircuit)
            record.behaviorScore = behavior
            record.scanScore = ProcessDebloatTrajectoryEngine.rollingScanScore(
                from: Array(state.recordsByDay.values),
                before: dayKey
            )
            record.verdict = ProcessDebloatTrajectoryEngine.verdict(
                behaviorScore: behavior,
                yesCount: yesCount,
                scanScore: record.scanScore,
                isPaused: isPaused,
                checkInSubmitted: true
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
        Dictionary(
            uniqueKeysWithValues: answers.filter { EveningCheckInQuestionID.all.contains($0.key) }
        )
    }

    // MARK: - Persistence

    private func persist() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.debloat.trajectory", userId: uid)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadState() -> ProcessDebloatTrajectoryState? {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.debloat.trajectory", userId: uid)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ProcessDebloatTrajectoryState.self, from: data)
    }
}
