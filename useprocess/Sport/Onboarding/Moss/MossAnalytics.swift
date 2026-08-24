import Foundation
import os

enum MossAnalytics {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "moss", category: "funnel")

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
}
