import Foundation

@MainActor
@Observable
final class ProcessStreakStore {
    static let shared = ProcessStreakStore()

    private(set) var snapshot: ProcessStreakSnapshot = .empty
    private var state = ProcessStreakState()

    private init() {
        state = loadState() ?? ProcessStreakState()
    }

    func reload() {
        state = loadState() ?? ProcessStreakState()
    }

    func sync(from plan: FaceOriginPlan?, now: Date = Date()) {
        ProcessDebloatTrajectoryStore.shared.sync(from: plan)
    }

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

    // MARK: - Persistence

    private func persist() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.streak", userId: uid)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
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
        weekCalendar.locale = Locale(identifier: "fr_FR")
        weekCalendar.firstWeekday = 2

        let today = weekCalendar.startOfDay(for: now)
        guard let interval = weekCalendar.dateInterval(of: .weekOfYear, for: today) else { return [] }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
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
                isComplete: completedKeys.contains(key) || record?.checkInSubmitted == true,
                isToday: weekCalendar.isDateInToday(dayStart),
                isFuture: dayStart > today,
                verdict: record?.verdict,
                compositeScore: record?.compositeScore
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
        formatter.locale = Locale(identifier: "fr_FR")
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
                isComplete: completedKeys.contains(key) || record?.checkInSubmitted == true,
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
