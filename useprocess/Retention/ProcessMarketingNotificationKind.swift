import Foundation

/// Campagnes locales marketing → non-payeurs (IDs `process.mkt.*`).
enum ProcessMarketingNotificationKind: String, CaseIterable, Identifiable {
    /// Notif ~1s après sortie app post-paywall — ouvre la roue.
    case paywallExitInstant = "paywall_exit_instant"
    case planReady = "plan_ready"
    case morningPuff = "morning_puff"
    case fomoLifetime = "fomo_lifetime"
    case offerAlmostGone = "offer_almost_gone"
    case lastChance19 = "last_chance_19"
    case spinAgain = "spin_again"
    case socialProof = "social_proof"
    case scanWasted = "scan_wasted"
    case weekendReset = "weekend_reset"
    case missYouValue = "miss_you_value"
    case priceAnchor = "price_anchor"
    case finalNudge = "final_nudge"
    case dormant = "dormant"

    var id: String { rawValue }

    /// Identifiant UNUserNotificationCenter.
    var notificationIdentifier: String {
        "process.mkt.\(rawValue)"
    }

    /// Valeur `userInfo["kind"]` pour le delegate.
    var userInfoKind: String {
        "marketing_\(rawValue)"
    }

    /// Hors série planifiée (gérée à part — ne pas cancel au reschedule).
    var isInstantExitChase: Bool {
        self == .paywallExitInstant
    }

    /// Tap → `PaywallSpinWinbackView` (roue).
    var opensSpinWheel: Bool {
        switch self {
        case .paywallExitInstant, .spinAgain:
            return true
        default:
            return false
        }
    }

    /// Destination au tap (offre lifetime). Mutuellement exclusif avec `opensSpinWheel`.
    var opensLifetimeOffer: Bool {
        switch self {
        case .paywallExitInstant, .spinAgain:
            return false
        default:
            return true
        }
    }

    /// Priorité plus haute = gardée en cas de collision jour / cap semaine 1.
    var retentionPriority: Int {
        switch self {
        case .paywallExitInstant: return 110
        case .planReady: return 100
        case .morningPuff: return 90
        case .offerAlmostGone: return 85
        case .fomoLifetime: return 80
        case .lastChance19: return 78
        case .spinAgain: return 76
        case .socialProof: return 70
        case .scanWasted: return 65
        case .weekendReset: return 60
        case .missYouValue: return 55
        case .priceAnchor: return 50
        case .finalNudge: return 45
        case .dormant: return 40
        }
    }

    /// Kinds de la série FOMO (sans la chase instantanée).
    static var seriesCases: [ProcessMarketingNotificationKind] {
        allCases.filter { !$0.isInstantExitChase }
    }

    @MainActor
    func title(firstName: String?) -> String {
        AppCopy.t("Ton suivi Process", en: "Your Process tracking")
    }

    @MainActor
    func body() -> String {
        AppCopy.t(
            "Retrouve tes observations et tes habitudes dans l’application.",
            en: "Find your observations and habits in the app."
        )
    }

    private static func resolvedFirstName(_ raw: String?) -> String? {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard OnboardingViewModel.isRealUserFirstName(trimmed) else { return nil }
        return trimmed
    }
}
