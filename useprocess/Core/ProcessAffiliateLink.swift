import Foundation

enum ProcessAffiliateLink {
    static func normalizeCode(_ raw: String) -> String {
        String(raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
            .prefix(24)
            .description
    }

    static func landingURL(code: String) -> URL {
        ProcessReferralLink.landingURL(code: code)
    }

    static func brandedShortURL(code: String) -> URL {
        ProcessReferralLink.brandedShortURL(code: code)
    }

    static func parseCode(from url: URL) -> String? {
        ProcessReferralLink.parseCode(from: url)
    }
}

@MainActor
enum ProcessAffiliateAttribution {
    private static let pendingKey = "affiliate.pendingCode"

    // Historical attribution is not re-applied after the program has been retired.
    static var pendingCode: String? { nil }
    static func clearPending() { UserDefaults.standard.removeObject(forKey: pendingKey) }
}
