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

    static var pendingCode: String? {
        guard let raw = UserDefaults.standard.string(forKey: pendingKey) else { return nil }
        let normalized = ProcessAffiliateLink.normalizeCode(raw)
        return normalized.isEmpty ? nil : normalized
    }

    static func capture(from url: URL) {
        guard let code = ProcessAffiliateLink.parseCode(from: url) else { return }
        storePending(code)
    }

    static func applyPendingIfNeeded(to viewModel: OnboardingViewModel) {
        guard let code = pendingCode else { return }
        if ProcessAffiliateLifetimePass.matches(code) {
            ProcessAffiliateLifetimePass.unlock()
            clearPending()
            viewModel.creatorCodeDraft = ProcessAffiliateLifetimePass.code
            viewModel.creatorCodeIsVerified = true
            viewModel.saveProgress()
            return
        }
        let current = viewModel.referralCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if current.isEmpty {
            viewModel.referralCode = code
            viewModel.saveProgress()
            ProcessAcquisitionAttribution.captureAffiliateCode(code)
            Task { @MainActor in
                ProcessAnalytics.trackReferralCodeApplied(source: "onboarding_affiliate")
            }
        }
    }

    static func clearPending() {
        UserDefaults.standard.removeObject(forKey: pendingKey)
    }

    private static func storePending(_ code: String) {
        let normalized = ProcessAffiliateLink.normalizeCode(code)
        guard !normalized.isEmpty else { return }
        if ProcessAffiliateLifetimePass.matches(normalized) {
            ProcessAffiliateLifetimePass.unlock()
            return
        }
        UserDefaults.standard.set(normalized, forKey: pendingKey)
        ProcessAcquisitionAttribution.captureAffiliateCode(normalized)
    }
}
