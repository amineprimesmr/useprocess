import SwiftUI

enum FaceScanWhoopRevealTiming {
    static let metricsStartDelay: TimeInterval = 0.18
    static let metricStagger: TimeInterval = 0.05
    static let chatMetricsStartDelay: TimeInterval = 1.05
    static let chatMetricStagger: TimeInterval = 0.36
    static let trendsStartDelay: TimeInterval = 0.42
    static let insightStartDelay: TimeInterval = 0.30
    static let scoreStepMs: UInt64 = 24

    static func metricsStartDelay(for style: FaceScanWhoopResultsStyle) -> TimeInterval {
        style == .chatThread ? chatMetricsStartDelay : metricsStartDelay
    }

    static func metricStagger(for style: FaceScanWhoopResultsStyle) -> TimeInterval {
        style == .chatThread ? chatMetricStagger : metricStagger
    }

    static var ringSpring: Animation {
        .spring(response: 0.56, dampingFraction: 0.86)
    }

    static var contentEase: Animation {
        .easeOut(duration: 0.28)
    }
}

private struct FaceScanResultsAnimateRevealKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var faceScanResultsAnimateReveal: Bool {
        get { self[FaceScanResultsAnimateRevealKey.self] }
        set { self[FaceScanResultsAnimateRevealKey.self] = newValue }
    }
}
