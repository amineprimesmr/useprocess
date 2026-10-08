import Foundation

/// Legacy resolver name retained for referral-code compatibility; the clipper program is retired.
@MainActor
final class AffiliateService {
    static let shared = AffiliateService()
    private init() {}

    func resolveCode(_ rawCode: String) async -> ProcessAffiliateResolveResult? {
        let normalized = ProcessAffiliateLink.normalizeCode(rawCode)
        guard !normalized.isEmpty, !ProcessAffiliateLifetimePass.matches(normalized),
              FirebaseBootstrap.isConfigured, ClaudeConfiguration.functionsBaseURL != nil else { return nil }
        guard let resolved = try? await AffiliateRemoteService.resolveCode(normalized),
              resolved.type == .referral else { return nil }
        return resolved
    }
}
