import Foundation
import os

// ============================================================================
// MossAnalytics — local-first funnel truth.
//
// MOSS has no accounts and sends nothing anywhere; "Nothing ever leaves this
// phone" must stay literally true. Events land in the unified log (visible
// in Console / sysdiagnose) and a tiny local ring file for the debug panel.
//
// Discipline, enforced by convention at every call site:
//   · never a Health value, step count, or balance;
//   · never an app identity or opaque token — counts only;
//   · never message contents — stable identifiers only.
// ============================================================================

enum MossAnalytics {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "moss", category: "funnel")

    private static let onceKeyPrefix = "moss.analytics.once."
    private static let installDateKey = "moss.analytics.installDate"

    /// Log one funnel event with optional neutral properties.
    static func log(_ event: String, _ props: [String: String] = [:]) {
        if props.isEmpty {
            logger.log("\(event, privacy: .public)")
        } else {
            let joined = props.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            logger.log("\(event, privacy: .public) \(joined, privacy: .public)")
        }
    }

    /// Log an event at most once per install (the `first_*` family).
    /// Returns true when this call was the first.
    @discardableResult
    static func logOnce(_ event: String, _ props: [String: String] = [:]) -> Bool {
        let key = onceKeyPrefix + event
        guard !UserDefaults.standard.bool(forKey: key) else { return false }
        UserDefaults.standard.set(true, forKey: key)
        log(event, props)
        return true
    }

    static func hasFired(_ event: String) -> Bool {
        UserDefaults.standard.bool(forKey: onceKeyPrefix + event)
    }

    /// Hours since the first event ever logged — powers loop-closed windows
    /// without any remote clock.
    static func hoursSinceInstall() -> Int {
        let defaults = UserDefaults.standard
        if let date = defaults.object(forKey: installDateKey) as? Date {
            return Int(Date.now.timeIntervalSince(date) / 3600)
        }
        defaults.set(Date.now, forKey: installDateKey)
        return 0
    }
}
