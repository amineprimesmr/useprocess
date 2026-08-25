import Foundation

@MainActor
final class AffiliateService {
    static let shared = AffiliateService()

    private static let visitorIdKey = "process.affiliate.visitorId"

    static var visitorId: String {
        if let existing = UserDefaults.standard.string(forKey: visitorIdKey),
           existing.count >= 8 {
            return existing
        }
        let generated = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let value = String(generated.prefix(32))
        UserDefaults.standard.set(value, forKey: visitorIdKey)
        return value
    }

    private init() {}

    func resolveCode(_ rawCode: String) async -> ProcessAffiliateResolveResult? {
        let normalized = ProcessAffiliateLink.normalizeCode(rawCode)
        guard !normalized.isEmpty else { return nil }
        guard !ProcessAffiliateLifetimePass.matches(normalized) else { return nil }

        guard FirebaseBootstrap.isConfigured,
              ClaudeConfiguration.functionsBaseURL != nil else {
            return nil
        }

        do {
            return try await AffiliateRemoteService.resolveCode(normalized)
        } catch {
            #if DEBUG
            print("[AffiliateService] resolve failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    func registerAffiliate(
        code: String,
        referredUserId: String,
        displayName: String?
    ) async throws {
        let normalized = ProcessAffiliateLink.normalizeCode(code)
        guard !normalized.isEmpty else { return }
        guard !ProcessAffiliateLifetimePass.matches(normalized) else { return }

        persistLocalReferredBy(code: normalized, userId: referredUserId, kind: .affiliate)
        ProcessAffiliateAttribution.clearPending()
        ProcessAcquisitionAttribution.captureAffiliateCode(normalized)

        guard FirebaseBootstrap.isConfigured,
              AuthUser.current != nil,
              ClaudeConfiguration.functionsBaseURL != nil else {
            markRemoteRegistrationPending(userId: referredUserId, code: normalized, kind: .affiliate)
            return
        }

        do {
            try await AffiliateRemoteService.registerAffiliate(
                code: normalized,
                displayName: displayName
            )
            clearRemoteRegistrationPending(userId: referredUserId)
        } catch let error as AffiliateRemoteError {
            if case .httpError(404, _) = error {
                clearRemoteRegistrationPending(userId: referredUserId)
            } else {
                markRemoteRegistrationPending(userId: referredUserId, code: normalized, kind: .affiliate)
            }
            throw error
        } catch {
            markRemoteRegistrationPending(userId: referredUserId, code: normalized, kind: .affiliate)
            throw error
        }
    }

    func retryPendingRemoteRegistration(displayName: String?) async {
        guard let userId = UserScopedStorage.currentUserId(),
              let pending = pendingRemoteRegistration(for: userId),
              pending.kind == .affiliate else {
            return
        }

        guard FirebaseBootstrap.isConfigured,
              AuthUser.current != nil,
              ClaudeConfiguration.functionsBaseURL != nil else {
            return
        }

        do {
            try await AffiliateRemoteService.registerAffiliate(
                code: pending.code,
                displayName: displayName
            )
            clearRemoteRegistrationPending(userId: userId)
        } catch let error as AffiliateRemoteError {
            if case .httpError(404, _) = error {
                clearRemoteRegistrationPending(userId: userId)
            }
            #if DEBUG
            print("[AffiliateService] retry register failed: \(error.localizedDescription)")
            #endif
        } catch {
            #if DEBUG
            print("[AffiliateService] retry register failed: \(error.localizedDescription)")
            #endif
        }
    }

    func referredByCode(for userId: String) -> String? {
        guard let stored = storedAcquisition(for: userId),
              stored.kind == .affiliate else {
            return nil
        }
        return stored.code
    }

    func trackPaywallReached() async {
        let raw = ProcessAcquisitionAttribution.snapshot.affiliateCode?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return }
        await AffiliateRemoteService.trackFunnel(event: "paywall", code: raw)
    }

    private func persistLocalReferredBy(
        code: String,
        userId: String,
        kind: ProcessAffiliateAttributionKind
    ) {
        let key = UserScopedStorage.key("acquisition.attributed", userId: userId)
        let payload = ProcessStoredAcquisitionCode(code: code, kind: kind, displayName: nil)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func storedAcquisition(for userId: String) -> ProcessStoredAcquisitionCode? {
        let key = UserScopedStorage.key("acquisition.attributed", userId: userId)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ProcessStoredAcquisitionCode.self, from: data)
    }

    private func pendingRemoteRegistrationKey(for userId: String) -> String {
        UserScopedStorage.key("acquisition.remoteRegistrationPending", userId: userId)
    }

    private func markRemoteRegistrationPending(
        userId: String,
        code: String,
        kind: ProcessAffiliateAttributionKind
    ) {
        let payload = ProcessStoredAcquisitionCode(code: code, kind: kind, displayName: nil)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: pendingRemoteRegistrationKey(for: userId))
        }
    }

    private func clearRemoteRegistrationPending(userId: String) {
        UserDefaults.standard.removeObject(forKey: pendingRemoteRegistrationKey(for: userId))
    }

    private func pendingRemoteRegistration(for userId: String) -> ProcessStoredAcquisitionCode? {
        guard let data = UserDefaults.standard.data(forKey: pendingRemoteRegistrationKey(for: userId)) else {
            return nil
        }
        return try? JSONDecoder().decode(ProcessStoredAcquisitionCode.self, from: data)
    }
}
