import Foundation

struct FaceScanCorrelationInsight: Identifiable, Hashable {
    let id: String
    let message: String
    let icon: String

    init(message: String, icon: String = "lightbulb.fill") {
        self.id = message
        self.message = message
        self.icon = icon
    }
}

enum FaceScanCorrelationEngine {

    static func insights(from history: [FaceScanResult]) -> [FaceScanCorrelationInsight] {
        guard history.count >= 3 else { return [] }

        var results: [FaceScanCorrelationInsight] = []

        if let sleepInsight = sleepUnderEyeCorrelation(history) {
            results.append(sleepInsight)
        }
        if let puffinessInsight = sleepPuffinessCorrelation(history) {
            results.append(puffinessInsight)
        }
        if let hrvInsight = hrvFatigueCorrelation(history) {
            results.append(hrvInsight)
        }
        if let trendInsight = weeklyTrendInsight(history) {
            results.append(trendInsight)
        }

        return results
    }

    private static func sleepUnderEyeCorrelation(_ history: [FaceScanResult]) -> FaceScanCorrelationInsight? {
        let withSleep = history.filter { ($0.sleepHoursAtScan ?? 0) > 0 }
        guard withSleep.count >= 3 else { return nil }

        let short = withSleep.filter { ($0.sleepHoursAtScan ?? 0) < 6 }
        let good = withSleep.filter { ($0.sleepHoursAtScan ?? 0) >= 7 }
        guard short.count >= 2, good.count >= 2 else { return nil }

        let shortAvg = average(short.map { Double(underEyeSignal($0)) })
        let goodAvg = average(good.map { Double(underEyeSignal($0)) })
        guard shortAvg - goodAvg >= 8 else { return nil }

        return FaceScanCorrelationInsight(
            message: "Tes cernes montent les nuits < 6 h (+\(Int(shortAvg - goodAvg)) pts en moyenne).",
            icon: "moon.zzz.fill"
        )
    }

    private static func sleepPuffinessCorrelation(_ history: [FaceScanResult]) -> FaceScanCorrelationInsight? {
        let withSleep = history.filter { ($0.sleepHoursAtScan ?? 0) > 0 }
        guard withSleep.count >= 3 else { return nil }

        let short = withSleep.filter { ($0.sleepHoursAtScan ?? 0) < 6 }
        let good = withSleep.filter { ($0.sleepHoursAtScan ?? 0) >= 7 }
        guard short.count >= 2, good.count >= 2 else { return nil }

        let shortAvg = average(short.map { Double(puffinessSignal($0)) })
        let goodAvg = average(good.map { Double(puffinessSignal($0)) })
        guard shortAvg - goodAvg >= 8 else { return nil }

        return FaceScanCorrelationInsight(
            message: "Gonflement plus marqué quand tu dors moins de 6 h.",
            icon: "drop.fill"
        )
    }

    private static func hrvFatigueCorrelation(_ history: [FaceScanResult]) -> FaceScanCorrelationInsight? {
        let withHRV = history.filter { ($0.hrvAtScan ?? 0) > 0 }
        guard withHRV.count >= 4 else { return nil }

        let median = medianValue(withHRV.compactMap(\.hrvAtScan))
        let lowHRV = withHRV.filter { ($0.hrvAtScan ?? 0) < median * 0.9 }
        let highHRV = withHRV.filter { ($0.hrvAtScan ?? 0) >= median }
        guard lowHRV.count >= 2, highHRV.count >= 2 else { return nil }

        let lowAvg = average(lowHRV.map { Double(underEyeSignal($0)) })
        let highAvg = average(highHRV.map { Double(underEyeSignal($0)) })
        guard lowAvg - highAvg >= 7 else { return nil }

        return FaceScanCorrelationInsight(
            message: "HRV basse = cernes plus visibles sur tes scans récents.",
            icon: "waveform.path.ecg"
        )
    }

    private static func weeklyTrendInsight(_ history: [FaceScanResult]) -> FaceScanCorrelationInsight? {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = history.filter { $0.createdAt >= weekAgo }
        let older = history.filter { $0.createdAt < weekAgo }
        guard recent.count >= 2, let oldestInWeek = recent.last, let before = older.first else { return nil }

        let delta = underEyeSignal(oldestInWeek) - underEyeSignal(before)
        if delta >= 10 {
            return FaceScanCorrelationInsight(
                message: "Cernes en hausse sur 7 jours (+\(delta) pts) — priorise le sommeil.",
                icon: "chart.line.uptrend.xyaxis"
            )
        }
        if delta <= -10 {
            return FaceScanCorrelationInsight(
                message: "Cernes en baisse sur 7 jours (\(delta) pts) — bonne trajectoire.",
                icon: "chart.line.downtrend.xyaxis"
            )
        }
        return nil
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func underEyeSignal(_ result: FaceScanResult) -> Int {
        result.relativeSignals?.underEyeFatigueDelta ?? result.markers.underEyeFatigueScore
    }

    private static func puffinessSignal(_ result: FaceScanResult) -> Int {
        result.relativeSignals?.puffinessDelta ?? result.markers.puffinessScore
    }

    private static func medianValue(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        return sorted[sorted.count / 2]
    }
}
