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
    /// Extension Apple accordée au filleul après son 1er abonnement.
    static let inviteeRewardDays = 7

    /// Extension Apple pour parrain hebdo / mensuel.
    static let referrerShortRewardDays = 14

    /// Extension Apple pour parrain annuel.
    static let referrerAnnualRewardDays = 30

    @MainActor
    static var rewardHeadline: String {
        AppCopy.t("Temps offert sur Apple", en: "Free Apple subscription time")
    }

    @MainActor
    static var referrerRewardSummary: String {
        AppCopy.t(
            "2 semaines offertes par parrainage (1 mois si tu es en abonnement annuel).",
            en: "2 free weeks per referral (1 free month on an annual plan)."
        )
    }

    @MainActor
    static var inviteeRewardSummary: String {
        AppCopy.t(
            "Ton ami gagne 7 jours offerts sur son abonnement Apple après son inscription.",
            en: "Your friend gets 7 free days on their Apple subscription after signing up."
        )
    }

    @MainActor
    static func rewardLabel(for duration: String?, status: ProcessReferralEntryStatus) -> String? {
        guard status == .accepted else { return nil }
        switch duration {
        case "monthly":
            return AppCopy.t("1 mois offert", en: "1 free month")
        case "two_week":
            return AppCopy.t("2 semaines offertes", en: "2 free weeks")
        case "weekly":
            return AppCopy.t("7 jours offerts", en: "7 free days")
        default:
            return AppCopy.t("Temps offert", en: "Free time added")
        }
    }
}
