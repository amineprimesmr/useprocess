import Foundation
import SwiftUI

enum ProfileChartMetric: String, CaseIterable, Identifiable {
    case weight = "Poids"
    case cortisol = "Cortisol"
    case recovery = "Cernes et fatigue"
    case retention = "Rétention"
    case definition = "Mâchoire & pommettes"
    case skin = "Peau"
    case effort = "Effort"

    var id: String { rawValue }

    @MainActor
    var title: String {
        switch self {
        case .weight: return AppCopy.t("Poids", en: "Weight")
        case .cortisol: return "Cortisol"
        case .recovery: return AppCopy.t("Cernes et fatigue", en: "Dark Circles & Fatigue")
        case .retention: return AppCopy.t("Rétention", en: "Water Retention")
        case .definition: return AppCopy.t("Mâchoire & pommettes", en: "Jawline & Cheekbones")
        case .skin: return AppCopy.t("Peau", en: "Skin")
        case .effort: return AppCopy.t("Effort", en: "Effort")
        }
    }

    static let profileDisplayOrder: [ProfileChartMetric] = [
        // .weight, // Temporairement masqué
        .cortisol,
        .recovery,
        .retention,
        .definition,
        .skin
        // .effort // Temporairement masqué
    ]

    var faceScanKind: FaceScanIndicators.Kind? {
        switch self {
        case .retention: return .retention
        case .recovery: return .recovery
        case .cortisol: return .stressLoad
        case .definition: return .definition
        case .skin: return .skin
        default: return nil
        }
    }

    @MainActor
    var summarySubtitle: String {
        switch self {
        case .weight: return AppCopy.t("poids actuel", en: "current weight")
        case .cortisol: return AppCopy.t("cortisol estimé", en: "estimated cortisol")
        case .recovery: return AppCopy.t("cernes et fatigue", en: "dark circles and fatigue")
        case .retention: return AppCopy.t("rétention d'eau", en: "water retention")
        case .definition: return AppCopy.t("définition faciale", en: "facial definition")
        case .skin: return AppCopy.t("qualité de peau", en: "skin quality")
        case .effort: return AppCopy.t("score d'activité", en: "activity score")
        }
    }

    @MainActor
    var emptySinglePointMessage: String {
        switch self {
        case .weight: return AppCopy.t("Une seule pesée — refais une mesure pour voir la courbe.", en: "Only one weigh-in—take another measurement to see the chart.")
        case .effort: return AppCopy.t("Un seul jour d'activité — continue pour voir la courbe.", en: "Only one day of activity—keep going to see the chart.")
        default: return AppCopy.t("Un seul scan — refais un scan pour voir la courbe.", en: "Only one scan—take another scan to see the chart.")
        }
    }

    @MainActor
    var emptyNoDataMessage: String {
        switch self {
        case .weight: return AppCopy.t("Ajoute ton poids dans Santé ou ton profil.", en: "Add your weight in Health or your profile.")
        case .effort: return AppCopy.t("Active Apple Santé pour suivre ton effort.", en: "Enable Apple Health to track your effort.")
        default: return AppCopy.t("Fais ton scan visage pour démarrer la courbe.", en: "Take a face scan to start your chart.")
        }
    }

    @MainActor
    var emptyPeriodTitle: String {
        switch self {
        case .weight: return AppCopy.t("Aucune pesée", en: "No Weigh-ins")
        case .effort: return AppCopy.t("Aucune activité", en: "No Activity")
        default: return AppCopy.t("Aucun scan", en: "No Scans")
        }
    }
}

enum ProfileChartVisualStyle {
    case splineGlow
    case lineArea
    case barTrend
    case dashedLine
}

extension FaceScanIndicators.WellnessZone {
    @MainActor
    var profileBadgeLabel: String {
        title.uppercased(with: ProcessAppLanguage.shared.locale)
    }

    var profileBadgeColor: Color {
        FaceScanWhoopPalette.ringColor(for: self)
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

    @MainActor
    var accessibilityLabel: String {
        switch self {
        case .kilograms: return AppCopy.t("Courbe de poids", en: "Weight chart")
        case .percent: return AppCopy.t("Courbe en pourcentage", en: "Percentage chart")
        case .hours: return AppCopy.t("Courbe de sommeil", en: "Sleep chart")
        }
    }
}

extension ProfileChartMetric {
    var axisStyle: ProfileChartAxisStyle {
        switch self {
        case .weight: return .kilograms
        case .effort: return .percent
        default: return .percent
        }
    }

    /// Pour l'affichage couleur delta : true = baisse favorable.
    var lowerDeltaIsPositive: Bool {
        switch self {
        case .weight, .retention, .recovery, .cortisol: return true
        case .definition, .skin, .effort: return false
        }
    }

    var showsChartArea: Bool {
        switch self {
        case .weight: return false
        default: return true
        }
    }

    var chartLineIsDashed: Bool {
        self == .weight
    }

    var deltaThreshold: Double {
        switch self {
        case .weight: return 0.1
        default: return 1
        }
    }

    func visualStyle(pointCount: Int) -> ProfileChartVisualStyle {
        switch self {
        case .weight: return .dashedLine
        case .cortisol: return .lineArea
        case .recovery: return .splineGlow
        case .retention: return .barTrend
        case .definition: return .splineGlow
        case .skin: return .splineGlow
        case .effort: return .lineArea
        }
    }

    func formattedChartValue(_ value: Double) -> (main: String, unit: String) {
        switch axisStyle {
        case .kilograms:
            let text = String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
            return (text, "kg")
        case .percent:
            return ("\(Int(value.rounded()))", "%")
        case .hours:
            return (formattedHoursParts(value).main, formattedHoursParts(value).unit)
        }
    }

    private func formattedHoursParts(_ value: Double) -> (main: String, unit: String) {
        let totalMinutes = Int((value * 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 { return ("\(hours)", "h") }
        return ("\(hours) h \(String(format: "%02d", minutes))", "")
    }

    func wellnessZone(for value: Double?) -> FaceScanIndicators.WellnessZone? {
        guard let value else { return nil }
        let percent = Int(value.rounded())

        if let kind = faceScanKind {
            if kind.higherIsWorse {
                switch kind {
                case .retention, .recovery:
                    switch percent {
                    case ..<48: return .optimal
                    case 48..<78: return .sufficient
                    default: return .insufficient
                    }
                case .stressLoad:
                    switch percent {
                    case ..<42: return .optimal
                    case 42..<78: return .sufficient
                    default: return .insufficient
                    }
                case .skin, .definition:
                    break
                }
            } else {
                return FaceScanIndicators.wellnessZone(forPercent: percent)
            }
        }

        if self == .effort {
            switch percent {
            case 70...: return .optimal
            case 40..<70: return .sufficient
            default: return .insufficient
            }
        }

        return nil
    }

    func chartLineColor(theme: AppTheme) -> Color {
        switch self {
        case .weight: return ProfileChartColors.weightViolet
        case .cortisol: return ProfileChartColors.cortisolOrange
        case .recovery: return ProfileChartColors.recoveryViolet
        case .retention: return ProfileChartColors.retentionBlue
        case .definition: return ProfileChartColors.definitionGold
        case .skin: return ProfileChartColors.skinRose
        case .effort: return ProfileChartColors.effortGreen
        }
    }

    func chartLineGradient(theme: AppTheme) -> LinearGradient {
        let base = chartLineColor(theme: theme)
        switch self {
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
        default:
            return LinearGradient(
                colors: [base, base.opacity(0.82)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    func chartAreaGradient(theme: AppTheme) -> LinearGradient {
        let base = chartLineColor(theme: theme)
        return LinearGradient(
            colors: [
                base.opacity(theme.isDark ? 0.28 : 0.22),
                base.opacity(theme.isDark ? 0.10 : 0.08),
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
    static let cortisolOrange = Color(red: 1.0, green: 0.55, blue: 0.35)
    static let recoveryViolet = Color(red: 0.55, green: 0.45, blue: 0.95)
    static let definitionGold = Color(red: 0.95, green: 0.78, blue: 0.35)
    static let skinRose = Color(red: 1.0, green: 0.65, blue: 0.72)
    static let effortGreen = Color(red: 0.35, green: 0.82, blue: 0.55)
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

    static func faceScanIndicatorHistory(
        from scans: [FaceScanResult],
        kind: FaceScanIndicators.Kind
    ) -> [ProfileAnalyticsPoint] {
        let calendar = Calendar.current
        var latestByDay: [Date: FaceScanResult] = [:]

        for scan in scans {
            let day = calendar.startOfDay(for: scan.createdAt)
            if let existing = latestByDay[day], existing.createdAt > scan.createdAt { continue }
            latestByDay[day] = scan
        }

        return latestByDay.keys.sorted().compactMap { day in
            guard let scan = latestByDay[day] else { return nil }
            let value = Double(FaceScanIndicators.displayPercent(for: kind, result: scan))
            guard value > 0 else { return nil }
            return ProfileAnalyticsPoint(
                id: "\(kind.rawValue)-\(dayKey(day))",
                date: day,
                value: value
            )
        }
    }

    static func retentionHistory(from scans: [FaceScanResult]) -> [ProfileAnalyticsPoint] {
        faceScanIndicatorHistory(from: scans, kind: .retention)
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
