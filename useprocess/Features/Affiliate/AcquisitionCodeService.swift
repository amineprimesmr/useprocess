import Foundation

@MainActor
enum AcquisitionCodeService {
    static func registerIfPresent(code: String, referredUserId: String, displayName: String?) async {
        guard let resolved = await AffiliateService.shared.resolveCode(code), resolved.type == .referral else { return }
        do {
            try await ReferralService.shared.registerReferral(
                referralCode: resolved.code, referredUserId: referredUserId, displayName: displayName
            )
        } catch {
            // ReferralService persists pending registrations for the next authenticated retry.
        }
    }

    static func retryPendingRemoteRegistration(displayName: String?) async {
        await ReferralService.shared.retryPendingRemoteRegistration(displayName: displayName)
    }
}
