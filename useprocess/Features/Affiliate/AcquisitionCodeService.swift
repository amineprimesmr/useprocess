import Foundation

/// Enregistre un code onboarding : créateur (affiliate) d'abord, parrainage utilisateur ensuite.
@MainActor
enum AcquisitionCodeService {
    static func registerIfPresent(
        code: String,
        referredUserId: String,
        displayName: String?
    ) async {
        let normalized = ProcessAffiliateLink.normalizeCode(code)
        guard !normalized.isEmpty else { return }
        guard !ProcessAffiliateLifetimePass.matches(normalized) else { return }

        if let resolved = await AffiliateService.shared.resolveCode(normalized) {
            switch resolved.type {
            case .affiliate:
                do {
                    try await AffiliateService.shared.registerAffiliate(
                        code: resolved.code,
                        referredUserId: referredUserId,
                        displayName: displayName
                    )
                    ProcessReferralAttribution.clearPending()
                    return
                } catch {
                    #if DEBUG
                    print("[AcquisitionCodeService] affiliate register failed: \(error.localizedDescription)")
                    #endif
                }
            case .referral:
                do {
                    try await ReferralService.shared.registerReferral(
                        referralCode: resolved.code,
                        referredUserId: referredUserId,
                        displayName: displayName
                    )
                    return
                } catch {
                    #if DEBUG
                    print("[AcquisitionCodeService] referral register failed: \(error.localizedDescription)")
                    #endif
                }
            }
        }

        do {
            try await AffiliateService.shared.registerAffiliate(
                code: normalized,
                referredUserId: referredUserId,
                displayName: displayName
            )
        } catch let error as AffiliateRemoteError {
            if case .httpError(404, _) = error {
                do {
                    try await ReferralService.shared.registerReferral(
                        referralCode: normalized,
                        referredUserId: referredUserId,
                        displayName: displayName
                    )
                } catch {
                    #if DEBUG
                    print("[AcquisitionCodeService] referral fallback failed: \(error.localizedDescription)")
                    #endif
                }
            }
        } catch {
            #if DEBUG
            print("[AcquisitionCodeService] affiliate fallback failed: \(error.localizedDescription)")
            #endif
        }
    }

    static func retryPendingRemoteRegistration(displayName: String?) async {
        await AffiliateService.shared.retryPendingRemoteRegistration(displayName: displayName)
        await ReferralService.shared.retryPendingRemoteRegistration(displayName: displayName)
    }
}
