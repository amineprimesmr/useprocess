import Foundation
import SwiftUI

enum ProfileChartMetric: String, CaseIterable, Identifiable {
    case weight = "Poids"
    case retention = "Rétention"

    var id: String { rawValue }

    var summarySubtitle: String {
        switch self {
        case .weight: return "poids actuel"
        case .retention: return "rétention d'eau"
        }
    }

    var emptySinglePointMessage: String {
        switch self {
        case .weight: return "Une seule pesée — refais une mesure pour voir la courbe."
        case .retention: return "Un seul scan — refais un scan pour voir la courbe."
        }
    }

    var emptyNoDataMessage: String {
        switch self {
        case .weight: return "Ajoute ton poids dans Santé ou ton profil."
        case .retention: return "Fais ton scan visage pour démarrer la courbe."
        }
    }

    var emptyPeriodTitle: String {
        switch self {
        case .weight: return "Aucune pesée"
        case .retention: return "Aucun scan"
        }
    }

    var syncHint: String {
        switch self {
        case .weight: return "Synchronisé depuis Apple Santé ou ton profil."
        case .retention: return "Basé sur tes scans visage Process."
        }
    }
}

enum ProfileChartAxisStyle {
    case kilograms
    case percent
    case hours

    func formatAxisLabel(_ value: Double) -> String {
        switch self {
        case .kilograms:
            return String(format: "%.0f", value)
        case .percent:
            return String(format: "%.0f", value)
        case .hours:
            return String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
        }
    }

    func formatSummary(_ value: Double) -> String {
        switch self {
        case .kilograms:
            return ProfileChartHistoryBuilder.formattedKilograms(value)
        case .percent:
            return "\(Int(value.rounded())) %"
        case .hours:
            return ProfileChartHistoryBuilder.formattedHours(value)
        }
    }

    func formatDelta(_ delta: Double) -> String {
        switch self {
        case .kilograms:
            return ProfileChartHistoryBuilder.formattedKilogramDelta(delta)
        case .percent:
            return ProfileChartHistoryBuilder.formattedPercentDelta(delta)
        case .hours:
            return ProfileChartHistoryBuilder.formattedHourDelta(delta)
        }
    }

    func defaultRange(for values: [Double]) -> (min: Double, max: Double) {
        guard let minV = values.min(), let maxV = values.max() else {
            switch self {
            case .kilograms: return (69, 73)
            case .percent: return (40, 80)
            case .hours: return (6, 9)
            }
        }
        if minV == maxV {
            switch self {
            case .kilograms: return (minV - 1, maxV + 1)
            case .percent: return (max(0, minV - 8), min(100, maxV + 8))
            case .hours: return (max(0, minV - 0.8), maxV + 0.8)
            }
        }
        let padding: Double
        switch self {
        case .kilograms:
            padding = max(0.25, (maxV - minV) * 0.18)
        case .percent:
            padding = max(4, (maxV - minV) * 0.15)
        case .hours:
            padding = max(0.3, (maxV - minV) * 0.18)
        }
        return (minV - padding, maxV + padding)
    }

    var accessibilityLabel: String {
        switch self {
        case .kilograms: return "Courbe de poids"
        case .percent: return "Courbe en pourcentage"
        case .hours: return "Courbe de sommeil"
        }
    }
}

extension ProfileChartMetric {
    var axisStyle: ProfileChartAxisStyle {
        switch self {
        case .weight: return .kilograms
        case .retention: return .percent
        }
    }

    /// Pour l'affichage couleur delta : true = baisse favorable.
    var lowerDeltaIsPositive: Bool { true }

    var showsChartArea: Bool {
        switch self {
        case .weight: return false
        case .retention: return true
        }
    }

    var chartLineIsDashed: Bool {
        switch self {
        case .weight: return true
        case .retention: return false
        }
    }

    func chartLineColor(theme: AppTheme) -> Color {
        switch self {
        case .weight: return ProfileChartColors.weightViolet
        case .retention: return ProfileChartColors.retentionBlue
        }
    }

    func chartLineGradient(theme: AppTheme) -> LinearGradient {
        switch self {
        case .weight:
            return LinearGradient(
                colors: [ProfileChartColors.weightViolet, ProfileChartColors.weightViolet.opacity(0.82)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .retention:
            return LinearGradient(
                colors: [
                    ProfileChartColors.retentionBlueDeep,
                    ProfileChartColors.retentionBlue,
                    ProfileChartColors.retentionBlueLight
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    func chartAreaGradient(theme: AppTheme) -> LinearGradient {
        LinearGradient(
            colors: [
                ProfileChartColors.retentionBlue.opacity(theme.isDark ? 0.28 : 0.22),
                ProfileChartColors.retentionBlueLight.opacity(theme.isDark ? 0.10 : 0.08),
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

enum ProfileChartColors {
    static let weightViolet = Color(red: 0.58, green: 0.40, blue: 0.96)
    static let retentionBlueDeep = Color(red: 0.18, green: 0.52, blue: 0.98)
    static let retentionBlue = Color(red: 0.33, green: 0.72, blue: 1.0)
    static let retentionBlueLight = Color(red: 0.55, green: 0.84, blue: 1.0)
}

enum ProfileChartHistoryBuilder {

    static func mergeWeightWithProfileFallback(
        history: [ProfileAnalyticsPoint],
        profileWeight: Double
    ) -> [ProfileAnalyticsPoint] {
        guard history.isEmpty, profileWeight > 0 else { return history.sorted { $0.date < $1.date } }
        return [
            ProfileAnalyticsPoint(
                id: "profile-weight",
                date: Calendar.current.startOfDay(for: Date()),
                value: profileWeight
            )
        ]
    }

    static func mergeWithProfileFallback(
        history: [ProfileAnalyticsPoint],
        profileWeight: Double
    ) -> [ProfileAnalyticsPoint] {
        mergeWeightWithProfileFallback(history: history, profileWeight: profileWeight)
    }

    static func retentionHistory(from scans: [FaceScanResult]) -> [ProfileAnalyticsPoint] {
        let calendar = Calendar.current
        var latestByDay: [Date: FaceScanResult] = [:]

        for scan in scans {
            let day = calendar.startOfDay(for: scan.createdAt)
            if let existing = latestByDay[day], existing.createdAt > scan.createdAt { continue }
            latestByDay[day] = scan
        }

        return latestByDay.keys.sorted().map { day in
            let scan = latestByDay[day]!
            let value = Double(FaceScanIndicators.displayPercent(for: .retention, result: scan))
            return ProfileAnalyticsPoint(
                id: "retention-\(dayKey(day))",
                date: day,
                value: value
            )
        }
    }

    static func visiblePoints(
        history: [ProfileAnalyticsPoint],
        range: ProfileAnalyticsRange,
        weekOffset: Int,
        includeZeroValues: Bool = false
    ) -> [ProfileAnalyticsPoint] {
        let calendar = Calendar.current
        let sorted = history
            .filter { includeZeroValues || $0.value > 0 }
            .sorted { $0.date < $1.date }

        switch range {
        case .week:
            let today = calendar.startOfDay(for: Date())
            guard let periodEnd = calendar.date(byAdding: .day, value: -weekOffset * 7, to: today),
                  let periodStart = calendar.date(byAdding: .day, value: -6, to: periodEnd) else {
                return sorted
            }
            return sorted.filter { $0.date >= periodStart && $0.date <= periodEnd }

        case .month:
            guard let cutoff = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: Date())) else {
                return sorted
            }
            return sorted.filter { $0.date >= cutoff }

        case .all:
            return sorted
        }
    }

    static func previousPeriodAverage(
        history: [ProfileAnalyticsPoint],
        range: ProfileAnalyticsRange,
        weekOffset: Int,
        includeZeroValues: Bool = false
    ) -> Double? {
        guard range == .week else { return nil }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let currentEnd = calendar.date(byAdding: .day, value: -weekOffset * 7, to: today),
              let currentStart = calendar.date(byAdding: .day, value: -6, to: currentEnd),
              let previousEnd = calendar.date(byAdding: .day, value: -7, to: currentStart),
              let previousStart = calendar.date(byAdding: .day, value: -6, to: previousEnd) else {
            return nil
        }

        let values = history
            .filter {
                (includeZeroValues || $0.value > 0)
                    && $0.date >= previousStart
                    && $0.date <= previousEnd
            }
            .map(\.value)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    static func average(in points: [ProfileAnalyticsPoint], includeZeroValues: Bool = false) -> Double? {
        let values = points.map(\.value).filter { includeZeroValues || $0 > 0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    static func formattedKilograms(_ value: Double) -> String {
        String(format: "%.1f kg", value).replacingOccurrences(of: ".", with: ",")
    }

    static func formattedHours(_ value: Double) -> String {
        let totalMinutes = Int((value * 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 { return "\(hours) h" }
        return "\(hours) h \(String(format: "%02d", minutes))"
    }

    static func formattedKilogramDelta(_ delta: Double) -> String {
        let sign = delta > 0 ? "+" : ""
        return sign + String(format: "%.1f kg", delta).replacingOccurrences(of: ".", with: ",")
    }

    static func formattedPercentDelta(_ delta: Double) -> String {
        let sign = delta > 0 ? "+" : ""
        return sign + "\(Int(delta.rounded())) pts"
    }

    static func formattedHourDelta(_ delta: Double) -> String {
        let sign = delta > 0 ? "+" : ""
        let hours = abs(delta)
        if hours < 1 {
            return sign + "\(Int((hours * 60).rounded())) min"
        }
        return sign + String(format: "%.1f h", hours).replacingOccurrences(of: ".", with: ",")
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

typealias ProfileWeightHistoryBuilder = ProfileChartHistoryBuilder
