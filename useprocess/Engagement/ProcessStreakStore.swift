import Foundation

@MainActor
@Observable
final class ProcessStreakStore {
    static let shared = ProcessStreakStore()

    private(set) var snapshot: ProcessStreakSnapshot = .empty
    private var state = ProcessStreakState()

    private init() {
        reload()
    }

    func reload() {
        state = loadState() ?? ProcessStreakState()
        refreshSnapshot(now: Date())
    }

    func sync(from plan: FaceOriginPlan?, now: Date = Date()) {
        guard let plan else {
            refreshSnapshot(now: now)
            return
        }

        var keys = Set<String>()
        for day in plan.calendar.weeks.flatMap(\.days) {
            guard let date = OriginPlanPresenter.calendarDate(for: day, in: plan) else { continue }
            guard !OriginPlanPresenter.isFutureJournalDate(date, relativeTo: now) else { continue }
            guard OriginPlanPresenter.isDayJournalComplete(plan: plan, day: day) else { continue }
            keys.insert(Self.dayKey(for: date))
        }

        state.completedDayKeys = keys
        state.longestStreak = max(state.longestStreak, Self.longestStreak(in: keys))
        persist()
        refreshSnapshot(plan: plan, now: now)
    }

    var displayStreak: Int {
        snapshot.currentStreak
    }

    // MARK: - Snapshot

    private func refreshSnapshot(plan: FaceOriginPlan? = nil, now: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let todayKey = Self.dayKey(for: today, calendar: calendar)
        let isTodayComplete = state.completedDayKeys.contains(todayKey)

        let current = Self.currentStreak(completedKeys: state.completedDayKeys, today: today, calendar: calendar)
        let week = Self.daySnapshots(
            endingAt: today,
            dayCount: 7,
            completedKeys: state.completedDayKeys,
            calendar: calendar
        )
        let month = Self.daySnapshots(
            endingAt: today,
            dayCount: 28,
            completedKeys: state.completedDayKeys,
            calendar: calendar
        )
        let calendarWeek = Self.calendarWeekSnapshots(
            completedKeys: state.completedDayKeys,
            now: now,
            calendar: calendar
        )

        let nextMilestone = ProcessStreakMilestone.catalog.first(where: { $0.days > current })
        let daysUntilNext = nextMilestone.map { $0.days - current }

        snapshot = ProcessStreakSnapshot(
            currentStreak: current,
            longestStreak: max(state.longestStreak, current),
            totalCompletedDays: state.completedDayKeys.count,
            isTodayComplete: isTodayComplete,
            todayProgress: todayProgress(plan: plan, now: now),
            week: week,
            calendarWeek: calendarWeek,
            month: month,
            nextMilestone: nextMilestone,
            daysUntilNextMilestone: daysUntilNext
        )
    }

    private func todayProgress(plan: FaceOriginPlan?, now: Date) -> Double {
        guard let plan,
              let day = OriginPlanPresenter.programDay(in: plan, for: now) ?? OriginPlanPresenter.todayDay(in: plan, date: now)
        else { return 0 }

        let tasks = OriginPlanPresenter.manualJournalTasks(from: day, plan: plan)
        guard !tasks.isEmpty else { return 0 }

        let completed = tasks.filter {
            plan.progress.status(for: $0.id, dayId: day.id) == .completed
        }.count
        return Double(completed) / Double(tasks.count)
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

    // MARK: - Calculs

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let dayValue = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, dayValue)
    }

    private static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
            .map { calendar.startOfDay(for: $0) }
    }

    static func currentStreak(
        completedKeys: Set<String>,
        today: Date = Calendar.current.startOfDay(for: Date()),
        calendar: Calendar = .current
    ) -> Int {
        var cursor = today
        if !completedKeys.contains(dayKey(for: cursor, calendar: calendar)),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) {
            cursor = calendar.startOfDay(for: yesterday)
        }

        var streak = 0
        while completedKeys.contains(dayKey(for: cursor, calendar: calendar)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = calendar.startOfDay(for: previous)
        }
        return streak
    }

    static func longestStreak(in completedKeys: Set<String>, calendar: Calendar = .current) -> Int {
        let dates = completedKeys.compactMap { date(from: $0, calendar: calendar) }.sorted()
        guard !dates.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for index in 1..<dates.count {
            let previous = dates[index - 1]
            let currentDate = dates[index]
            let delta = calendar.dateComponents([.day], from: previous, to: currentDate).day ?? 0
            if delta == 1 {
                current += 1
                longest = max(longest, current)
            } else if delta > 1 {
                current = 1
            }
        }

        return longest
    }

    private static func daySnapshots(
        endingAt endDate: Date,
        dayCount: Int,
        completedKeys: Set<String>,
        calendar: Calendar
    ) -> [ProcessStreakDaySnapshot] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")

        return (0..<dayCount).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDate) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let key = dayKey(for: dayStart, calendar: calendar)
            return ProcessStreakDaySnapshot(
                id: key,
                date: dayStart,
                weekdaySymbol: formatter.string(from: dayStart).uppercased(),
                isComplete: completedKeys.contains(key),
                isToday: calendar.isDateInToday(dayStart),
                isFuture: dayStart > calendar.startOfDay(for: Date())
            )
        }
    }

    private static func calendarWeekSnapshots(
        completedKeys: Set<String>,
        now: Date,
        calendar: Calendar
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
            return ProcessStreakDaySnapshot(
                id: key,
                date: dayStart,
                weekdaySymbol: formatter.string(from: dayStart).uppercased(),
                isComplete: completedKeys.contains(key),
                isToday: weekCalendar.isDateInToday(dayStart),
                isFuture: dayStart > today
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
        week: [],
        calendarWeek: [],
        month: [],
        nextMilestone: ProcessStreakMilestone.catalog.first,
        daysUntilNextMilestone: ProcessStreakMilestone.catalog.first?.days
    )
}
