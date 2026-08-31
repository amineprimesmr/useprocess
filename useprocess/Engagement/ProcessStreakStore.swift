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
        let displayCounts = ProcessStreakLaunchPolicy.resolvedDisplayCounts(
            currentStreak: trajectory.currentStreak,
            totalValidatedDays: trajectory.totalValidatedDays
        )
        let longest = max(state.longestStreak, trajectory.longestStreak, displayCounts.current)
        if state.completedDayKeys != eligibleKeys || state.longestStreak != longest {
            state.completedDayKeys = eligibleKeys
            state.longestStreak = longest
            persist()
        }

        let updated = ProcessStreakSnapshot(
            currentStreak: displayCounts.current,
            longestStreak: longest,
            totalCompletedDays: displayCounts.total,
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

    var displayStreak: Int { snapshot.currentStreak }

    var displayValidatedDays: Int { snapshot.totalCompletedDays }

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

    /// Semaine affichée sur le profil — lundi → dimanche.
    static func buildProfileWeekSnapshots(
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

    /// Semaine calendaire du streak profil — lundi → dimanche (semaine ISO / FR).
    static func buildProgramStreakWindow(
        plan: FaceOriginPlan?,
        progress: PlanProgressSnapshot,
        recordsByDay: [String: DebloatDayRecord],
        completedKeys: Set<String>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ProfileProgramStreakDay] {
        var weekCalendar = calendar
        weekCalendar.locale = ProcessAppLanguage.shared.locale
        weekCalendar.firstWeekday = 2

        let today = weekCalendar.startOfDay(for: now)
        guard let interval = weekCalendar.dateInterval(of: .weekOfYear, for: today) else { return [] }

        let planStart = plan?.calendar.startedAt.map { weekCalendar.startOfDay(for: $0) }

        return (0..<7).compactMap { offset in
            guard let date = weekCalendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            let dayStart = weekCalendar.startOfDay(for: date)
            let key = dayKey(for: dayStart, calendar: weekCalendar)
            let record = recordsByDay[key]
            let isComplete = completedKeys.contains(key) || record?.hasScan == true
            let isToday = weekCalendar.isDateInToday(dayStart)
            let isFuture = dayStart > today
            let isMissed: Bool = {
                guard !isFuture, !isToday, !isComplete else { return false }
                if let planStart, dayStart < planStart { return false }
                return true
            }()

            let programDayNumber: Int = {
                if let plan, let programDay = OriginPlanPresenter.programDay(in: plan, for: dayStart) {
                    return programDay.globalDayIndex + 1
                }
                return offset + 1
            }()

            return ProfileProgramStreakDay(
                id: offset + 1,
                programDayNumber: programDayNumber,
                date: dayStart,
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
