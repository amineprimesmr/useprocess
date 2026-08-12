import Foundation

/// Format countdown for hydration Live Activity / Dynamic Island (no seconds).
enum ProcessHydrationCountdownFormatting {
    static func compactLabel(for remaining: TimeInterval) -> String {
        let total = max(0, Int(remaining.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60

        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "0m"
    }
}
