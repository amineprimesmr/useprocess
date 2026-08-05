import Foundation

@MainActor
@Observable
final class ProcessStreakStore {
    static let shared = ProcessStreakStore()

    private(set) var snapshot: ProcessStreakSnapshot = .empty
    private var state = ProcessStreakState()
    private var persistenceGeneration: UInt64 = 0

    private init() {
        state = loadState() ?? ProcessStreakState()
    }

    func reload() {
        state = loadState() ?? ProcessStreakState()
    }

    /// No-op — la trajectoire debloat pousse déjà le snapshot via `applyTrajectorySnapshot`.
    func sync(from plan: FaceOriginPlan?, now: Date = Date()) {}

    /// Appelé par ProcessDebloatTrajectoryStore après recalcul.
    func applyTrajectorySnapshot(
        _ trajectory: DebloatTrajectorySnapshot,
        eligibleKeys: Set<String>,
        recordsByDay: [String: DebloatDayRecord]
    ) {
        let longest = max(state.longestStreak, trajectory.longestStreak)
        if state.completedDayKeys != eligibleKeys || state.longestStreak != longest {
            state.completedDayKeys = eligibleKeys
            state.longestStreak = longest
            persist()
        }

        let updated = ProcessStreakSnapshot(
            currentStreak: trajectory.currentStreak,
            longestStreak: longest,
            totalCompletedDays: trajectory.totalValidatedDays,
            isTodayComplete: trajectory.isTodayComplete,
            todayProgress: trajectory.todayProgress,
            calendarWeek: trajectory.calendarWeek,
            month: buildMonthSnapshots(
                completedKeys: eligibleKeys,
                recordsByDay: recordsByDay,
                now: Date()
            ),
            nextMilestone: trajectory.nextMilestone,
            daysUntilNextMilestone: trajectory.daysUntilNextMilestone,
            todayVerdict: trajectory.todayVerdict,
            todayCompositeScore: trajectory.todayCompositeScore,
            trajectoryTrend: trajectory.trajectoryTrend,
            velocityLabel: trajectory.velocityLabel
        )

        if snapshot != updated {
            snapshot = updated
        }
    }

    var displayStreak: Int {
        snapshot.currentStreak
    }

    var displayValidatedDays: Int {
        snapshot.totalCompletedDays
    }

    // MARK: - Persistence

    private func persist() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.streak", userId: uid)
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

    private func loadState() -> ProcessStreakState? {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.streak", userId: uid)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ProcessStreakState.self, from: data)
    }

    // MARK: - Calculs partagés

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let dayValue = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, dayValue)
    }

    static func buildCalendarWeekSnapshots(
        completedKeys: Set<String>,
        recordsByDay: [String: DebloatDayRecord],
        now: Date,
        calendar: Calendar = .current
    ) -> [ProcessStreakDaySnapshot] {
        var weekCalendar = calendar
        weekCalendar.locale = ProcessAppLanguage.shared.locale
        weekCalendar.firstWeekday = 2

        let today = weekCalendar.startOfDay(for: now)
        guard let interval = weekCalendar.dateInterval(of: .weekOfYear, for: today) else { return [] }

        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")

        return (0..<7).compactMap { offset in
            guard let date = weekCalendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            let dayStart = weekCalendar.startOfDay(for: date)
            let key = dayKey(for: dayStart, calendar: weekCalendar)
            let record = recordsByDay[key]
            return ProcessStreakDaySnapshot(
                id: key,
                date: dayStart,
                weekdaySymbol: formatter.string(from: dayStart).uppercased(),
                isComplete: completedKeys.contains(key),
                isToday: weekCalendar.isDateInToday(dayStart),
                isFuture: dayStart > today,
                verdict: record?.verdict,
                compositeScore: record?.compositeScore
            )
        }
    }

    /// Semaine affichée sur le profil — dimanche → samedi (design streak).
    static func buildProfileWeekSnapshots(
        completedKeys: Set<String>,
        recordsByDay: [String: DebloatDayRecord],
        now: Date,
        calendar: Calendar = .current
    ) -> [ProcessStreakDaySnapshot] {
        var weekCalendar = calendar
        weekCalendar.locale = ProcessAppLanguage.shared.locale
        weekCalendar.firstWeekday = 1

        let today = weekCalendar.startOfDay(for: now)
        guard let interval = weekCalendar.dateInterval(of: .weekOfYear, for: today) else { return [] }

        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.setLocalizedDateFormatFromTemplate("EEE")

        return (0..<7).compactMap { offset in
            guard let date = weekCalendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            let dayStart = weekCalendar.startOfDay(for: date)
            let key = dayKey(for: dayStart, calendar: weekCalendar)
            let record = recordsByDay[key]
            let label = formatter.string(from: dayStart)
                .replacingOccurrences(of: ".", with: "")
                .uppercased()
            return ProcessStreakDaySnapshot(
                id: key,
                date: dayStart,
                weekdaySymbol: String(label.prefix(3)),
                isComplete: completedKeys.contains(key),
                isToday: weekCalendar.isDateInToday(dayStart),
                isFuture: dayStart > today,
                verdict: record?.verdict,
                compositeScore: record?.compositeScore
            )
        }
    }

    /// Fenêtre de 7 jours du programme debloat — alignée sur `elapsedProgramDays`.
    static func buildProgramStreakWindow(
        plan: FaceOriginPlan?,
        progress: PlanProgressSnapshot,
        recordsByDay: [String: DebloatDayRecord],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ProfileProgramStreakDay] {
        guard let plan, progress.hasPlan, progress.totalProgramDays > 0 else { return [] }

        let today = calendar.startOfDay(for: now)
        let total = progress.totalProgramDays
        let currentDay = plan.calendar.startedAt != nil
            ? max(1, progress.elapsedProgramDays)
            : 1

        let endDay = min(total, max(7, currentDay + 3))
        let startDay = max(1, endDay - 6)
        let finalEnd = min(total, startDay + 6)

        return (startDay...finalEnd).compactMap { programDayNumber in
            let globalIndex = programDayNumber - 1
            guard let programDay = plan.calendar.day(globalIndex: globalIndex) else { return nil }

            let date: Date
            if let mapped = OriginPlanPresenter.calendarDate(for: programDay, in: plan) {
                date = calendar.startOfDay(for: mapped)
            } else if let startedAt = plan.calendar.startedAt {
                date = calendar.date(byAdding: .day, value: globalIndex, to: calendar.startOfDay(for: startedAt)) ?? today
            } else {
                date = today
            }

            let key = dayKey(for: date, calendar: calendar)
            let record = recordsByDay[key]
            let isComplete = record.map {
                $0.countsAsValidatedDay(
                    consecutiveCardioMissesBefore: ProcessDebloatValidation.consecutiveCardioMisses(
                        before: $0.dayKey,
                        in: recordsByDay
                    )
                )
            } == true
            let isToday = calendar.isDate(date, inSameDayAs: today)
            let isFuture = programDayNumber > currentDay
            let isMissed = !isFuture && !isToday && !isComplete && programDayNumber <= currentDay

            return ProfileProgramStreakDay(
                id: programDayNumber,
                programDayNumber: programDayNumber,
                date: date,
                isComplete: isComplete,
                isToday: isToday,
                isFuture: isFuture,
                isMissed: isMissed
            )
        }
    }

    private func buildMonthSnapshots(
        completedKeys: Set<String>,
        recordsByDay: [String: DebloatDayRecord],
        now: Date,
        calendar: Calendar = .current
    ) -> [ProcessStreakDaySnapshot] {
        let today = calendar.startOfDay(for: now)
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")

        return (0..<28).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let key = Self.dayKey(for: dayStart, calendar: calendar)
            let record = recordsByDay[key]
            return ProcessStreakDaySnapshot(
                id: key,
                date: dayStart,
                weekdaySymbol: formatter.string(from: dayStart).uppercased(),
                isComplete: completedKeys.contains(key),
                isToday: calendar.isDateInToday(dayStart),
                isFuture: dayStart > today,
                verdict: record?.verdict,
                compositeScore: record?.compositeScore
            )
        }
    }
}

private extension ProcessStreakSnapshot {
    static let empty = ProcessStreakSnapshot(
        currentStreak: 0,
        longestStreak: 0,
        totalCompletedDays: 0,
        isTodayComplete: false,
        todayProgress: 0,
        calendarWeek: [],
        month: [],
        nextMilestone: ProcessStreakMilestone.catalog.first,
        daysUntilNextMilestone: ProcessStreakMilestone.catalog.first?.days,
        todayVerdict: nil,
        todayCompositeScore: 0,
        trajectoryTrend: .unknown,
        velocityLabel: TrajectoryTrend.unknown.label
    )
}
