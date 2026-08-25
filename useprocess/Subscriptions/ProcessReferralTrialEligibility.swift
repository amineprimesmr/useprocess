import Foundation

/// 3 jours d’essai annuel après un code créateur / parrainage validé.
/// Le bras test `paywall-annual-trial-ab` débloque le même essai sans code.
@MainActor
enum ProcessReferralTrialEligibility {
    static let trialDays = 3

    private static let unlockedKey = "process.referral.annual_trial_unlocked"
    private static let verifiedCodeKey = "process.referral.annual_trial_code"

    static var isUnlocked: Bool {
        UserDefaults.standard.bool(forKey: unlockedKey)
    }

    static var verifiedCode: String? {
        let code = UserDefaults.standard.string(forKey: verifiedCodeKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return code.isEmpty ? nil : code
    }

    static func unlock(code: String) {
        let normalized = ProcessReferralCode.normalize(code)
        guard ProcessReferralCode.isValid(normalized) else { return }
        guard !ProcessAffiliateLifetimePass.matches(normalized) else { return }
        let wasUnlocked = isUnlocked
        UserDefaults.standard.set(true, forKey: unlockedKey)
        UserDefaults.standard.set(normalized, forKey: verifiedCodeKey)
        guard !wasUnlocked else { return }
        ProcessAnalytics.capture("referral_annual_trial_unlocked", properties: [
            "code": normalized,
            "trial_days": trialDays
        ])
        NotificationCenter.default.post(name: .processReferralAnnualTrialDidChange, object: nil)
    }

    static func lock() {
        guard isUnlocked else { return }
        UserDefaults.standard.set(false, forKey: unlockedKey)
        UserDefaults.standard.removeObject(forKey: verifiedCodeKey)
        NotificationCenter.default.post(name: .processReferralAnnualTrialDidChange, object: nil)
    }

    /// Revalide un code déjà attribué (lien, onboarding, paywall).
    @discardableResult
    static func syncFromResolvedCode(_ raw: String?) -> Bool {
        let normalized = ProcessReferralCode.normalize(raw ?? "")
        guard ProcessReferralCode.isValid(normalized) else { return isUnlocked }
        unlock(code: normalized)
        return true
    }

    /// Résout le code d’attribution. Débloque l’essai seulement si le code existe.
    @discardableResult
    static func refreshByResolvingAttributedCode() async -> Bool {
        if isUnlocked { return true }

        let candidates = attributedCodeCandidates
        guard !candidates.isEmpty else { return false }

        for code in candidates {
            if ProcessAffiliateLifetimePass.matches(code) { continue }
            if let resolved = await AffiliateService.shared.resolveCode(code) {
                unlock(code: resolved.code)
                return true
            }
        }
        return false
    }

    private static var attributedCodeCandidates: [String] {
        var seen = Set<String>()
        var codes: [String] = []
        let snapshot = ProcessAcquisitionAttribution.snapshot
        for raw in [
            snapshot.affiliateCode,
            snapshot.referralCode,
            snapshot.lastReferralCode,
            ProcessAffiliateAttribution.pendingCode,
            ProcessReferralAttribution.pendingCode,
            verifiedCode
        ] {
            let normalized = ProcessReferralCode.normalize(raw ?? "")
            guard ProcessReferralCode.isValid(normalized),
                  !ProcessAffiliateLifetimePass.matches(normalized),
                  !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            codes.append(normalized)
        }
        return codes
    }
}

extension Notification.Name {
    static let processReferralAnnualTrialDidChange = Notification.Name(
        "process.referral.annualTrialDidChange"
    )
}
