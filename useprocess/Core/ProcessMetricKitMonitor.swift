import MetricKit
import OSLog

/// Métriques système agrégées, sans contenu utilisateur ni identifiant personnel.
final class ProcessMetricKitMonitor: NSObject, MXMetricManagerSubscriber {
    static let shared = ProcessMetricKitMonitor()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.useprocess",
        category: "MetricKit"
    )
    private var isStarted = false

    private override init() {
        super.init()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        logger.info("MetricKit received \(payloads.count, privacy: .public) metric payload(s)")
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let crashCount = payloads.reduce(0) { result, payload in
            result + (payload.crashDiagnostics?.count ?? 0)
        }
        logger.error(
            "MetricKit received \(payloads.count, privacy: .public) diagnostic payload(s), \(crashCount, privacy: .public) crash(es)"
        )
    }
}
