import Foundation

enum FaceScanCadence {
    /// Délai minimum entre deux scans (1 = quotidien).
    static let intervalDays = 1

    static func daysUntilNextScan(since lastScan: Date, now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let elapsed = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastScan), to: calendar.startOfDay(for: now)).day ?? 0
        return max(0, intervalDays - elapsed)
    }

    static func isScanDue(since lastScan: Date?, now: Date = Date()) -> Bool {
        guard let lastScan else { return true }
        let calendar = Calendar.current
        if calendar.isDateInToday(lastScan) { return false }
        let elapsed = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastScan), to: calendar.startOfDay(for: now)).day ?? 0
        return elapsed >= intervalDays
    }

    static func nextScanDate(after lastScan: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: intervalDays, to: calendar.startOfDay(for: lastScan))
            ?? lastScan.addingTimeInterval(Double(intervalDays) * 86_400)
    }

    /// Libellé court pour l’état du prochain scan.
    static func statusLabel(since lastScan: Date?, now: Date = Date()) -> String {
        guard let lastScan else { return "Premier scan à faire" }
        let calendar = Calendar.current
        if calendar.isDateInToday(lastScan) { return "Scan enregistré aujourd'hui" }
        if isScanDue(since: lastScan, now: now) { return "Scan du jour à faire" }
        let remaining = daysUntilNextScan(since: lastScan, now: now)
        if remaining == 1 { return "Prochain scan demain" }
        return "Prochain scan dans \(remaining) j"
    }

    static func nextScanTarget(after lastScan: Date?, calendar: Calendar = .current) -> Date? {
        guard let lastScan else { return nil }
        return nextScanDate(after: lastScan, calendar: calendar)
    }

    static func timeUntilNextScan(since lastScan: Date?, now: Date = Date(), calendar: Calendar = .current) -> TimeInterval? {
        guard let lastScan else { return nil }
        let target = nextScanDate(after: lastScan, calendar: calendar)
        return max(0, target.timeIntervalSince(now))
    }

    static func countdownLabel(since lastScan: Date?, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let lastScan else { return "Premier scan à faire" }
        if isScanDue(since: lastScan, now: now) { return "Scan disponible" }
        guard let interval = timeUntilNextScan(since: lastScan, now: now, calendar: calendar) else {
            return "Premier scan à faire"
        }
        return formatCountdown(interval)
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
              !isScanDue(since: lastScan, now: now),
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
        let start = calendar.startOfDay(for: lastScan)
        guard let end = calendar.date(byAdding: .day, value: intervalDays, to: start) else { return 1 }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }

    static func nextScanHeadline(
        since lastScan: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        guard let lastScan else { return "Premier scan à faire" }
        if isScanDue(since: lastScan, now: now) { return "Scan disponible" }
        guard let target = nextScanTarget(after: lastScan, calendar: calendar) else {
            return "Premier scan à faire"
        }
        if calendar.isDateInTomorrow(target) { return "Demain" }
        if calendar.isDateInToday(target) { return "Plus tard aujourd'hui" }
        return target.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }
}
