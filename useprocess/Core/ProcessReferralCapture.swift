import Foundation
import UIKit

/// Liens et messages de parrainage partagés entre l'app et le site.
enum ProcessReferralLink {
    static let landingHost = "useprocess.xyz"
    static let joinHost = "join.useprocess.xyz"
    static let joinPathPrefix = "/join/"

    static func landingURL(code: String) -> URL {
        let normalized = normalizeCode(code)
        return URL(string: "https://\(landingHost)\(joinPathPrefix)\(normalized)")!
    }

    /// Lien ultra-court — actif quand join.useprocess.xyz pointe vers Vercel.
    static func brandedShortURL(code: String) -> URL {
        let normalized = normalizeCode(code)
        return URL(string: "https://\(joinHost)/\(normalized)")!
    }

    static func normalizeCode(_ raw: String) -> String {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty else { return cleaned }

        if cleaned.contains("-") {
            return cleaned.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        }

        let alnum = cleaned.filter { $0.isLetter || $0.isNumber }
        guard alnum.count > 4 else { return alnum }
        let split = alnum.index(alnum.startIndex, offsetBy: 4)
        return "\(alnum[..<split])-\(alnum[split...])"
    }

    static func displayCode(from raw: String) -> String {
        normalizeCode(raw)
    }

    static func parseCode(from url: URL) -> String? {
        if url.scheme == "process", url.host == "referral" {
            if let item = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value,
               !item.isEmpty {
                return normalizeCode(item)
            }
        }

        if let host = url.host?.lowercased(),
           host == landingHost || host == joinHost || host.hasSuffix(".\(landingHost)") {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if host == joinHost, !path.isEmpty,
               path.lowercased() != "get", path.lowercased() != "telecharger" {
                return normalizeCode(path)
            }
            if path.lowercased().hasPrefix("join/") {
                let code = String(path.dropFirst(5))
                if !code.isEmpty { return normalizeCode(code) }
            }
            if path == "get" || path == "telecharger" || path.isEmpty {
                if let item = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "ref" || $0.name == "code" })?
                    .value,
                   !item.isEmpty {
                    return normalizeCode(item)
                }
            }
        }

        return nil
    }

    static func parseCode(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let parsed = parseCode(from: url) {
            return parsed
        }

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            let matches = detector.matches(in: trimmed, options: [], range: range)
            for match in matches {
                if let url = match.url, let parsed = parseCode(from: url) {
                    return parsed
                }
            }
        }

        let joinPattern = #/(?:https?:\/\/)?(?:join\.)?useprocess\.xyz(?:/join)?/([A-Za-z0-9-]+)/#
        if let match = trimmed.firstMatch(of: joinPattern) {
            return normalizeCode(String(match.1))
        }

        let codePattern = #/\b([A-Z0-9]{2,6}-[A-Z0-9]{3,8})\b/#
        if let match = trimmed.uppercased().firstMatch(of: codePattern) {
            return normalizeCode(String(match.1))
        }

        return nil
    }
}

/// Capture et applique un code parrainage entrant (lien, presse-papiers).
@MainActor
enum ProcessReferralAttribution {
    private static let pendingKey = "referral.pendingCode"

    static var pendingCode: String? {
        guard let raw = UserDefaults.standard.string(forKey: pendingKey) else { return nil }
        let normalized = ProcessReferralLink.normalizeCode(raw)
        return normalized.isEmpty ? nil : normalized
    }

    static func capture(from url: URL) {
        guard let code = ProcessReferralLink.parseCode(from: url) else { return }
        storePending(code)
    }

    static func captureFromClipboardIfNeeded() {
        guard pendingCode == nil else { return }
        guard UIPasteboard.general.hasStrings else { return }
        guard let string = UIPasteboard.general.string else { return }
        guard string.localizedCaseInsensitiveContains("useprocess")
            || string.localizedCaseInsensitiveContains("process://referral")
            || string.range(
                of: "[A-Z0-9]{2,6}-[A-Z0-9]{3,8}",
                options: [.regularExpression, .caseInsensitive]
            ) != nil else { return }
        guard let code = ProcessReferralLink.parseCode(from: string) else { return }
        storePending(code)
    }

    static func captureOnAppLaunchIfNeeded() {
        captureFromClipboardIfNeeded()
    }

    static func applyPendingIfNeeded(to viewModel: OnboardingViewModel) {
        guard let code = pendingCode else { return }
        let current = viewModel.referralCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if current.isEmpty {
            viewModel.referralCode = code
            viewModel.saveProgress()
        }
    }

    static func clearPending() {
        UserDefaults.standard.removeObject(forKey: pendingKey)
    }

    private static func storePending(_ code: String) {
        let normalized = ProcessReferralLink.normalizeCode(code)
        guard !normalized.isEmpty else { return }
        UserDefaults.standard.set(normalized, forKey: pendingKey)
    }
}

extension Notification.Name {
    static let processReferralCodeCaptured = Notification.Name("processReferralCodeCaptured")
}
