import Foundation

enum FaceScanCadence {
    static let intervalDays = 3

    static func daysUntilNextScan(since lastScan: Date, now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let elapsed = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastScan), to: calendar.startOfDay(for: now)).day ?? 0
        return max(0, intervalDays - elapsed)
    }

    static func isScanDue(since lastScan: Date?, now: Date = Date()) -> Bool {
        guard let lastScan else { return true }
        let calendar = Calendar.current
        let elapsed = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastScan), to: calendar.startOfDay(for: now)).day ?? 0
        return elapsed >= intervalDays
    }

    static func nextScanDate(after lastScan: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: intervalDays, to: calendar.startOfDay(for: lastScan))
            ?? lastScan.addingTimeInterval(Double(intervalDays) * 86_400)
    }
}
