import Foundation

/// Format unique des codes parrainage ami — 5 caractères alphanumériques.
enum ProcessReferralCode {
    static let length = 5

    private static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func normalize(_ raw: String) -> String {
        String(
            raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
                .filter { $0.isLetter || $0.isNumber }
                .prefix(length)
        )
    }

    static func isValid(_ raw: String) -> Bool {
        normalize(raw).count == length
    }

    /// Génère un code stable à 5 caractères à partir de l’identifiant utilisateur.
    static func makeCode(userId: String, username: String? = nil) -> String {
        let tag = ProcessUsernameTag.normalize(username ?? "")
        let seed = "\(userId)|\(tag)"
        var state = fnv1a64(seed)

        var chars: [Character] = []
        chars.reserveCapacity(length)
        while chars.count < length {
            state = mix(state)
            let index = Int(state % UInt64(alphabet.count))
            chars.append(alphabet[index])
        }
        return String(chars)
    }

    private static func fnv1a64(_ value: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }

    private static func mix(_ value: UInt64) -> UInt64 {
        var state = value
        state ^= state >> 33
        state &*= 0xff51afd7ed558ccd
        state ^= state >> 33
        state &*= 0xc4ceb9fe1a85ec53
        state ^= state >> 33
        return state
    }
}

enum ProcessReferralEntryStatus: String, Codable, Equatable {
    case pending
    case accepted

    @MainActor var label: String {
        switch self {
        case .pending: AppCopy.t("En attente", en: "Pending")
        case .accepted: AppCopy.t("Actif", en: "Active")
        }
    }
}

struct ProcessReferralEntry: Identifiable, Codable, Equatable {
    let id: String
    var displayName: String
    var invitedAt: Date
    var status: ProcessReferralEntryStatus
    var rewardLabel: String?

    var maskedName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 2 else { return trimmed }
        let first = trimmed.prefix(2)
        let last = trimmed.suffix(1)
        return "\(first)******\(last)"
    }
}

struct ProcessReferralSnapshot: Codable, Equatable {
    var referralCode: String
    var entries: [ProcessReferralEntry]
    var pendingCount: Int
    var acceptedCount: Int
    var commissionStats: ProcessReferralCommissionStats

    static let empty = ProcessReferralSnapshot(
        referralCode: "",
        entries: [],
        pendingCount: 0,
        acceptedCount: 0,
        commissionStats: .empty
    )
}

enum ProcessReferralProgramTerms {
    /// Commission nette après ~30 % de frais store.
    static let netFactor = 0.70
    static let commissionRate = 0.40
    static let holdDays = 30

    /// Prix de référence du simulateur (abonnement annuel — non affiché dans l’UI).
    static let simulatorReferencePlanPrice: Double = 34.99

    static var commissionPercentLabel: String {
        AppCopy.tSync("40 %", en: "40%")
    }

    @MainActor
    static var referencePlanPrice: String {
        SubscriptionService.shared.referralRewardDisplayPrice
    }

    @MainActor
    static var referencePlanPriceValue: Double {
        parseDisplayPrice(referencePlanPrice) ?? 9.99
    }

    /// Commission estimée par paiement d’un ami (40 % du net).
    @MainActor
    static func estimatedCommissionPerPayment(planPrice: Double? = nil) -> Double {
        let gross = planPrice ?? referencePlanPriceValue
        return gross * netFactor * commissionRate
    }

    @MainActor
    static var commissionPerPaymentLabel: String {
        formattedCurrency(estimatedCommissionPerPayment())
    }

    @MainActor
    static var headline: String {
        AppCopy.t(
            "\(commissionPercentLabel) de commission à vie",
            en: "\(commissionPercentLabel) lifetime commission"
        )
    }

    @MainActor
    static var subtitle: String {
        AppCopy.t(
            "Sur chaque abonnement payé par tes amis — achat initial et renouvellements.",
            en: "On every paid subscription from your friends — initial purchase and renewals."
        )
    }

    @MainActor
    static func rewardLabel(for _: String?, status: ProcessReferralEntryStatus) -> String? {
        guard status == .accepted else { return nil }
        return commissionPercentLabel
    }

    /// Revenu simulé (tous amis × commission sur le prix de référence du simulateur).
    @MainActor
    static func formattedSimulatedRecurring(friendCount: Int) -> String {
        formattedSimulatorTotal(friendCount: friendCount)
    }

    @MainActor
    static func simulatorCommissionPerFriend() -> Double {
        estimatedCommissionPerPayment(planPrice: simulatorReferencePlanPrice)
    }

    @MainActor
    static var simulatorCommissionPerFriendLabel: String {
        formattedCurrency(simulatorCommissionPerFriend())
    }

    @MainActor
    static func formattedSimulatorTotal(friendCount: Int) -> String {
        let total = simulatorCommissionPerFriend() * Double(max(0, friendCount))
        return formattedCurrency(total)
    }

    static func formattedCents(_ cents: Int, currency: String = "EUR") -> String {
        let decimal = Decimal(cents) / 100
        return SubscriptionConfiguration.formatPaywallPrice(decimal: decimal, currencyCode: currency)
    }

    static func formattedCurrency(_ amount: Double, currency: String = "EUR") -> String {
        SubscriptionConfiguration.formatPaywallPrice(decimal: Decimal(amount), currencyCode: currency)
    }

    private static func parseDisplayPrice(_ raw: String) -> Double? {
        var cleaned = raw
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.contains(",") && !cleaned.contains(".") {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        }
        return Double(cleaned)
    }
}

struct ProcessReferralCommissionStats: Codable, Equatable {
    var pendingCents: Int
    var payableCents: Int
    var paidCents: Int
    var lifetimeCents: Int
    var activeSubscribers: Int

    static let empty = ProcessReferralCommissionStats(
        pendingCents: 0,
        payableCents: 0,
        paidCents: 0,
        lifetimeCents: 0,
        activeSubscribers: 0
    )
}

struct ProcessReferralDashboardResponse: Decodable, Equatable {
    let ok: Bool
    let pendingCount: Int?
    let acceptedCount: Int?
    let stats: ProcessReferralDashboardStats?
    let holdDays: Int?
}

struct ProcessReferralDashboardStats: Decodable, Equatable {
    let pendingCents: Int
    let payableCents: Int
    let paidCents: Int
    let lifetimeCents: Int
    let activeSubscribers: Int
}
