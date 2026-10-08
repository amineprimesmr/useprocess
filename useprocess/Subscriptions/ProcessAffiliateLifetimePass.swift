import Foundation

/// Code **affiliés** : accès lifetime offert, hors commissions.
///
/// Ne jamais passer ce code dans `ProcessAcquisitionAttribution`,
/// ni `AcquisitionCodeService`.
enum ProcessAffiliateLifetimePass {
    /// Code à donner aux affiliés. Alphabet parrainage (pas de I / O / 0 / 1).
    static let code = "CREW7"

    /// Identifiant local — pas un SKU StoreKit, pas un produit RevenueCat.
    static let productIdentifier = "process.pass.affiliate_lifetime"

    private static let unlockedKey = "process.affiliate.lifetime_pass.unlocked"
    private static let codeKey = "process.affiliate.lifetime_pass.code"

    static var isUnlocked: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: unlockedKey)
        #else
        // Production access comes from Apple purchases or RevenueCat-managed entitlements.
        return false
        #endif
    }

    static func matches(_ raw: String) -> Bool {
        #if DEBUG
        let normalized = ProcessReferralCode.normalize(raw)
        return normalized == code
        #else
        return false
        #endif
    }

    /// Alias explicite — même logique que `matches`, pour les call sites paywall / resolve.
    static func isLifetimePassCode(_ raw: String) -> Bool {
        matches(raw)
    }

    /// Persiste l’accès et active le premium local. Idempotent.
    @MainActor
    static func unlock() {
        guard matches(code) else { return }
        let wasUnlocked = isUnlocked
        UserDefaults.standard.set(true, forKey: unlockedKey)
        UserDefaults.standard.set(code, forKey: codeKey)
        SubscriptionService.shared.activateAffiliateLifetimePass()
        guard !wasUnlocked else { return }
        ProcessAnalytics.capture("affiliate_lifetime_pass_unlocked", properties: [
            "code": code
        ])
        NotificationCenter.default.post(name: .processAffiliateLifetimePassDidUnlock, object: nil)
    }
}

extension Notification.Name {
    static let processAffiliateLifetimePassDidUnlock = Notification.Name(
        "process.affiliate.lifetimePassDidUnlock"
    )
}
