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
        let name = Self.resolvedFirstName(firstName)
        switch self {
        case .paywallExitInstant:
            if let name {
                return AppCopy.t("\(name), reviens tout de suite", en: "\(name), come back right now")
            }
            return AppCopy.t("Reviens tout de suite", en: "Come back right now")
        case .planReady:
            if let name {
                return AppCopy.t("\(name), ton plan t’attend", en: "\(name), your plan is waiting")
            }
            return AppCopy.t("Ton plan t’attend", en: "Your plan is waiting")
        case .morningPuff:
            return AppCopy.t("Visage gonflé ce matin ?", en: "Puffy face this morning?")
        case .fomoLifetime:
            return AppCopy.t("Offre à vie encore dispo", en: "Lifetime access still available")
        case .offerAlmostGone:
            return AppCopy.t("Tu as laissé 19€ sur la table", en: "You left €19 on the table")
        case .lastChance19:
            return AppCopy.t("Dernière chance — 19€ à vie", en: "Last chance — €19 lifetime")
        case .spinAgain:
            return AppCopy.t("Retente ta chance", en: "Try your luck again")
        case .socialProof:
            let n = TransformationCaseStudyCatalog.transformedPeopleCount
            return AppCopy.t("+\(n) personnes ont dégonflé", en: "+\(n) people already debloated")
        case .scanWasted:
            return AppCopy.t("Ton scan dort dans l’app", en: "Your scan is sitting in the app")
        case .weekendReset:
            return AppCopy.t("Week-end debloat", en: "Debloat weekend")
        case .missYouValue:
            return AppCopy.t("Toujours gonflé le matin ?", en: "Still puffy in the morning?")
        case .priceAnchor:
            return AppCopy.t("Moins cher qu’un sérum", en: "Cheaper than a serum")
        case .finalNudge:
            return AppCopy.t("On garde ta place 24h", en: "We’re holding your spot 24h")
        case .dormant:
            return AppCopy.t("Ton visage a changé depuis ?", en: "Has your face changed since?")
        }
    }

    @MainActor
    func body() -> String {
        switch self {
        case .paywallExitInstant:
            return AppCopy.t(
                "La roue t’attend. Tourne-la maintenant — l’accès à vie peut encore tomber.",
                en: "The wheel is waiting. Spin it now — lifetime access can still drop."
            )
        case .planReady:
            return AppCopy.t(
                "Ton scan est analysé. Débloque l’accès pour lancer le debloat.",
                en: "Your scan is analyzed. Unlock access to start debloating."
            )
        case .morningPuff:
            return AppCopy.t(
                "Les 72 premières heures comptent. Ton protocole est prêt.",
                en: "The first 72 hours matter. Your protocol is ready."
            )
        case .fomoLifetime:
            return AppCopy.t(
                "Accès à 19€ une fois — pas un abonnement.",
                en: "Access for €19 once — not a subscription."
            )
        case .offerAlmostGone:
            return AppCopy.t(
                "L’accès à vie était à 19€. Rouvre avant qu’elle disparaisse.",
                en: "Lifetime access was €19. Reopen before it disappears."
            )
        case .lastChance19:
            return AppCopy.t(
                "Plus d’abonnement. Un paiement. Accès pour toujours.",
                en: "No subscription. One payment. Access forever."
            )
        case .spinAgain:
            return AppCopy.t(
                "La roue peut encore te donner l’accès à vie.",
                en: "The wheel can still unlock lifetime access."
            )
        case .socialProof:
            return AppCopy.t(
                "Elles ont débloqué leur plan. Ton scan est déjà fait — il manque juste l’accès.",
                en: "They unlocked their plan. Your scan is done — you just need access."
            )
        case .scanWasted:
            return AppCopy.t(
                "Rétention, cortisol, potentiel… analysés. Débloque l’accès pour agir.",
                en: "Retention, cortisol, potential… analyzed. Unlock access to act."
            )
        case .weekendReset:
            return AppCopy.t(
                "48h pour calmer la rétention. Débloque ton plan maintenant.",
                en: "48h to calm retention. Unlock your plan now."
            )
        case .missYouValue:
            return AppCopy.t(
                "On attaque rétention + cortisol — pas des crèmes. 19€ à vie encore possible.",
                en: "We target retention + cortisol — not creams. €19 lifetime still possible."
            )
        case .priceAnchor:
            return AppCopy.t(
                "Un paiement de 19€. Accès coach + scans + plan, à vie.",
                en: "One €19 payment. Coach + scans + plan, for life."
            )
        case .finalNudge:
            return AppCopy.t(
                "Après ça, l’offre à vie peut ne plus s’afficher. Ouvre l’app.",
                en: "After this, the lifetime offer may stop showing. Open the app."
            )
        case .dormant:
            return AppCopy.t(
                "Reviens scanner. Si tu débloques, l’offre 19€ peut encore s’appliquer.",
                en: "Come scan again. If you unlock, the €19 offer may still apply."
            )
        }
    }

    private static func resolvedFirstName(_ raw: String?) -> String? {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard OnboardingViewModel.isRealUserFirstName(trimmed) else { return nil }
        return trimmed
    }
}
