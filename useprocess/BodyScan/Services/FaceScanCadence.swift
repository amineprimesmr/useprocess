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
}
