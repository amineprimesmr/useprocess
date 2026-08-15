import Foundation

enum ProcessReferralEntryStatus: String, Codable, Equatable {
    case pending
    case accepted

    @MainActor var label: String {
        switch self {
        case .pending: AppCopy.t("En attente", en: "Pending")
        case .accepted: AppCopy.t("Validé", en: "Verified")
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
    var redeemedRewardIDs: [String]
    var pendingCount: Int
    var acceptedCount: Int

    var redeemedRewardIDSet: Set<String> {
        Set(redeemedRewardIDs)
    }

    static let empty = ProcessReferralSnapshot(
        referralCode: "",
        entries: [],
        redeemedRewardIDs: [],
        pendingCount: 0,
        acceptedCount: 0
    )
}

enum ProcessReferralProgramTerms {
    /// L’invité n’a aucun avantage — seul le parrain est récompensé.
    static let inviteeRewardDays = 0

    /// Extension promo pour parrain hebdo / mensuel.
    static let referrerShortRewardDays = 30

    /// Extension promo pour parrain annuel.
    static let referrerAnnualRewardDays = 365

    @MainActor
    static var cashAmount: String {
        SubscriptionService.shared.referralRewardDisplayPrice
    }

    @MainActor
    static var rewardHeadline: String {
        AppCopy.t("Les conditions", en: "The terms")
    }

    @MainActor
    static var perFriendHeadline: String {
        AppCopy.t("Gagne \(cashAmount) /ami.", en: "Earn \(cashAmount) /friend.")
    }

    @MainActor
    static var referrerRewardSummary: String {
        let price = cashAmount
        return AppCopy.t(
            "Chaque ami qui prend un abonnement te rapporte \(price). Plus tu en parraines, plus tu gagnes.",
            en: "Every friend who starts a subscription earns you \(price). The more you refer, the more you earn."
        )
    }

    @MainActor
    static func rewardLabel(for _: String?, status: ProcessReferralEntryStatus) -> String? {
        guard status == .accepted else { return nil }
        return AppCopy.t("+\(cashAmount)", en: "+\(cashAmount)")
    }
}
