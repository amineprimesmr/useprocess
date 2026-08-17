import Foundation

@MainActor
final class ReferralService {
    static let shared = ReferralService()

    private init() {}

    func registerReferral(
        referralCode: String,
        referredUserId: String,
        displayName: String? = nil
    ) async throws {
        let normalized = ProcessReferralLink.normalizeCode(referralCode)
        guard !normalized.isEmpty else { return }

        persistLocalReferredBy(code: normalized, userId: referredUserId)
        ProcessReferralAttribution.clearPending()
        ProcessAcquisitionAttribution.captureReferralCode(normalized)

        guard FirebaseBootstrap.isConfigured,
              AuthUser.current != nil,
              ClaudeConfiguration.functionsBaseURL != nil else {
            markRemoteRegistrationPending(userId: referredUserId, code: normalized)
            return
        }

        do {
            try await ReferralRemoteService.register(
                referralCode: normalized,
                displayName: displayName
            )
            clearRemoteRegistrationPending(userId: referredUserId)
            await confirmSubscriptionRewardsIfNeeded()
        } catch let error as ReferralRemoteError {
            if case .httpError(404, _) = error {
                clearRemoteRegistrationPending(userId: referredUserId)
            } else {
                markRemoteRegistrationPending(userId: referredUserId, code: normalized)
            }
            throw error
        } catch {
            markRemoteRegistrationPending(userId: referredUserId, code: normalized)
            throw error
        }
    }

    func syncReferrerProgram(
        referralCode: String,
        displayName: String?
    ) async {
        guard FirebaseBootstrap.isConfigured,
              AuthUser.current != nil,
              ClaudeConfiguration.functionsBaseURL != nil else {
            return
        }

        do {
            try await ReferralRemoteService.syncProgram(
                referralCode: referralCode,
                displayName: displayName
            )
        } catch {
            #if DEBUG
            print("[ReferralService] syncProgram failed: \(error.localizedDescription)")
            #endif
        }
    }

    func confirmSubscriptionRewardsIfNeeded() async {
        guard FirebaseBootstrap.isConfigured,
              AuthUser.current != nil,
              ClaudeConfiguration.functionsBaseURL != nil,
              SubscriptionService.shared.subscriptionStatus.isActive else {
            return
        }

        do {
            let granted = try await ReferralRemoteService.confirmSubscription()
            if granted {
                await SubscriptionService.shared.checkSubscriptionStatus()
            }
        } catch {
            #if DEBUG
            print("[ReferralService] confirmSubscription failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Retries a failed remote registration after onboarding or when the referrer syncs their code.
    func retryPendingRemoteRegistration(displayName: String?) async {
        guard let userId = UserScopedStorage.currentUserId(),
              let code = pendingRemoteRegistrationCode(for: userId) else {
            return
        }

        guard FirebaseBootstrap.isConfigured,
              AuthUser.current != nil,
              ClaudeConfiguration.functionsBaseURL != nil else {
            return
        }

        do {
            try await ReferralRemoteService.register(
                referralCode: code,
                displayName: displayName
            )
            clearRemoteRegistrationPending(userId: userId)
            await confirmSubscriptionRewardsIfNeeded()
        } catch let error as ReferralRemoteError {
            if case .httpError(404, _) = error {
                clearRemoteRegistrationPending(userId: userId)
            }
            #if DEBUG
            print("[ReferralService] retry register failed: \(error.localizedDescription)")
            #endif
        } catch {
            #if DEBUG
            print("[ReferralService] retry register failed: \(error.localizedDescription)")
            #endif
        }
    }

    func referredByCode(for userId: String) -> String? {
        let key = UserScopedStorage.key("referral.referredBy", userId: userId)
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        let normalized = ProcessReferralLink.normalizeCode(raw)
        return normalized.isEmpty ? nil : normalized
    }

    private func persistLocalReferredBy(code: String, userId: String) {
        let key = UserScopedStorage.key("referral.referredBy", userId: userId)
        UserDefaults.standard.set(code, forKey: key)
    }

    private func pendingRemoteRegistrationKey(for userId: String) -> String {
        UserScopedStorage.key("referral.remoteRegistrationPending", userId: userId)
    }

    private func markRemoteRegistrationPending(userId: String, code: String) {
        UserDefaults.standard.set(code, forKey: pendingRemoteRegistrationKey(for: userId))
    }

    private func clearRemoteRegistrationPending(userId: String) {
        UserDefaults.standard.removeObject(forKey: pendingRemoteRegistrationKey(for: userId))
    }

    private func pendingRemoteRegistrationCode(for userId: String) -> String? {
        guard let raw = UserDefaults.standard.string(forKey: pendingRemoteRegistrationKey(for: userId)) else {
            return nil
        }
        let normalized = ProcessReferralLink.normalizeCode(raw)
        return normalized.isEmpty ? nil : normalized
    }
}
