import Foundation

enum FaceScanCadence {
    /// 1 scan par jour civil.
    static let intervalDays = 1
    /// Déverrouillage du scan du jour (matin, même lumière) — pas à minuit.
    static let dailyUnlockHour = 6
    static let dailyUnlockMinute = 0

    static func daysUntilNextScan(since lastScan: Date, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let elapsed = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lastScan),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return max(0, intervalDays - elapsed)
    }

    static func isScanDue(since lastScan: Date?, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let lastScan else { return true }
        if calendar.isDate(lastScan, inSameDayAs: now) { return false }
        guard let unlock = todayUnlockDate(now: now, calendar: calendar) else { return true }
        return now >= unlock
    }

    static func hasScanToday(in history: [FaceScanResult], now: Date = Date(), calendar: Calendar = .current) -> Bool {
        hasScan(on: now, in: history, calendar: calendar)
    }

    static func hasScan(on date: Date, in history: [FaceScanResult], calendar: Calendar = .current) -> Bool {
        history.contains { calendar.isDate($0.createdAt, inSameDayAs: date) }
    }

    static func todayUnlockDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        calendar.date(
            bySettingHour: dailyUnlockHour,
            minute: dailyUnlockMinute,
            second: 0,
            of: now
        )
    }

    static func nextScanDate(after lastScan: Date, calendar: Calendar = .current) -> Date {
        let lastDay = calendar.startOfDay(for: lastScan)
        let nextDay = calendar.date(byAdding: .day, value: intervalDays, to: lastDay) ?? lastScan
        return calendar.date(
            bySettingHour: dailyUnlockHour,
            minute: dailyUnlockMinute,
            second: 0,
            of: nextDay
        ) ?? nextDay
    }

    /// Libellé court pour l’état du prochain scan.
    @MainActor
    static func statusLabel(since lastScan: Date?, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let lastScan else { return AppCopy.t("Premier scan à faire", en: "First scan to do") }
        if calendar.isDate(lastScan, inSameDayAs: now) {
            return AppCopy.t("Scan enregistré aujourd'hui", en: "Scan saved today")
        }
        if isScanDue(since: lastScan, now: now, calendar: calendar) {
            return AppCopy.t("Scan du jour à faire", en: "Today's scan to do")
        }
        return AppCopy.t("Prochain scan demain matin", en: "Next scan tomorrow morning")
    }

    static func nextScanTarget(after lastScan: Date?, calendar: Calendar = .current) -> Date? {
        guard let lastScan else { return nil }
        return nextScanDate(after: lastScan, calendar: calendar)
    }

    static func timeUntilNextScan(since lastScan: Date?, now: Date = Date(), calendar: Calendar = .current) -> TimeInterval? {
        guard let lastScan else { return nil }
        if isScanDue(since: lastScan, now: now, calendar: calendar) { return 0 }
        let target = nextScanDate(after: lastScan, calendar: calendar)
        return max(0, target.timeIntervalSince(now))
    }

    @MainActor
    static func countdownLabel(since lastScan: Date?, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let lastScan else { return AppCopy.t("Premier scan à faire", en: "First scan to do") }
        if isScanDue(since: lastScan, now: now, calendar: calendar) {
            return AppCopy.t("Scan disponible", en: "Scan available")
        }
        guard let interval = timeUntilNextScan(since: lastScan, now: now, calendar: calendar) else {
            return AppCopy.t("Premier scan à faire", en: "First scan to do")
        }
        return formatCountdownCompact(interval)
    }

    /// Countdown sans secondes — carte « Dernier scan ».
    static func formatCountdownCompact(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        if minutes > 0 {
            return AppCopy.tSync("\(minutes) min", en: "\(minutes) min")
        }
        return AppCopy.tSync("< 1 min", en: "< 1 min")
    }

    static func formatCountdown(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        }
        if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        }
        return String(format: "%ds", seconds)
    }

    struct CountdownComponents: Equatable {
        let hours: Int
        let minutes: Int
        let seconds: Int
    }

    static func countdownComponents(
        since lastScan: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CountdownComponents? {
        guard let lastScan,
              !isScanDue(since: lastScan, now: now, calendar: calendar),
              let interval = timeUntilNextScan(since: lastScan, now: now, calendar: calendar)
        else { return nil }

        let total = max(0, Int(interval.rounded(.down)))
        return CountdownComponents(
            hours: total / 3600,
            minutes: (total % 3600) / 60,
            seconds: total % 60
        )
    }

    static func intervalProgress(
        since lastScan: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Double {
        let end = nextScanDate(after: lastScan, calendar: calendar)
        let total = end.timeIntervalSince(lastScan)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(lastScan) / total))
    }

    @MainActor
    static func nextScanHeadline(
        since lastScan: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        guard let lastScan else { return AppCopy.t("Premier scan à faire", en: "First scan to do") }
        if isScanDue(since: lastScan, now: now, calendar: calendar) {
            return AppCopy.t("Scan disponible", en: "Scan available")
        }
        guard let target = nextScanTarget(after: lastScan, calendar: calendar) else {
            return AppCopy.t("Premier scan à faire", en: "First scan to do")
        }
        if calendar.isDateInTomorrow(target) {
            return AppCopy.t("Demain matin", en: "Tomorrow morning")
        }
        if calendar.isDate(target, inSameDayAs: now) {
            return AppCopy.t("Ce matin", en: "This morning")
        }
        let df = DateFormatter()
        df.locale = ProcessAppLanguage.shared.locale
        df.setLocalizedDateFormatFromTemplate("EEEE d MMM")
        return df.string(from: target)
    }
}
