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

        for _ in 0..<8 {
            var chars: [Character] = []
            chars.reserveCapacity(length)
            while chars.count < length {
                state = mix(state)
                let index = Int(state % UInt64(alphabet.count))
                chars.append(alphabet[index])
            }
            let candidate = String(chars)
            if !ProcessAffiliateLifetimePass.matches(candidate) {
                return candidate
            }
        }
        return "X7PRC"
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

enum ProcessReferralRewardDuration: String, Codable, Equatable {
    case monthly
    case yearly
}

struct ProcessReferralEntry: Identifiable, Codable, Equatable {
    let id: String
    var displayName: String
    var invitedAt: Date
    var status: ProcessReferralEntryStatus
    var rewardDuration: ProcessReferralRewardDuration?
    var rewardLabel: String?

    var maskedName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 2 else { return trimmed }
        let first = trimmed.prefix(2)
        let last = trimmed.suffix(1)
        return "\(first)******\(last)"
    }
}

struct ProcessReferralRewardSummary: Equatable {
    var monthsEarned: Int
    var yearsEarned: Int

    static let empty = ProcessReferralRewardSummary(monthsEarned: 0, yearsEarned: 0)

    static func from(entries: [ProcessReferralEntry]) -> ProcessReferralRewardSummary {
        var months = 0
        var years = 0
        for entry in entries where entry.status == .accepted {
            switch entry.rewardDuration {
            case .yearly:
                years += 1
            case .monthly, .none:
                months += 1
            }
        }
        return ProcessReferralRewardSummary(monthsEarned: months, yearsEarned: years)
    }

    @MainActor
    var displayLabel: String {
        switch (monthsEarned, yearsEarned) {
        case (0, 0):
            return AppCopy.t("Aucune récompense", en: "No rewards yet")
        case (0, 1):
            return AppCopy.t("1 an offert", en: "1 year free")
        case (0, let y) where y > 1:
            return AppCopy.t("\(y) ans offerts", en: "\(y) years free")
        case (1, 0):
            return AppCopy.t("1 mois offert", en: "1 month free")
        case (let m, 0) where m > 1:
            return AppCopy.t("\(m) mois offerts", en: "\(m) months free")
        default:
            var parts: [String] = []
            if monthsEarned > 0 {
                parts.append(
                    monthsEarned == 1
                        ? AppCopy.t("1 mois", en: "1 month")
                        : AppCopy.t("\(monthsEarned) mois", en: "\(monthsEarned) months")
                )
            }
            if yearsEarned > 0 {
                parts.append(
                    yearsEarned == 1
                        ? AppCopy.t("1 an", en: "1 year")
                        : AppCopy.t("\(yearsEarned) ans", en: "\(yearsEarned) years")
                )
            }
            let joined = parts.joined(separator: AppCopy.t(" · ", en: " · "))
            return AppCopy.t("\(joined) offerts", en: "\(joined) free")
        }
    }
}

struct ProcessReferralSnapshot: Codable, Equatable {
    var referralCode: String
    var entries: [ProcessReferralEntry]
    var pendingCount: Int
    var acceptedCount: Int

    var rewardSummary: ProcessReferralRewardSummary {
        ProcessReferralRewardSummary.from(entries: entries)
    }

    static let empty = ProcessReferralSnapshot(
        referralCode: "",
        entries: [],
        pendingCount: 0,
        acceptedCount: 0
    )
}

enum ProcessReferralProgramTerms {
    private static let annualProductIDs: Set<String> = [
        SubscriptionConfiguration.annualProductID,
        SubscriptionConfiguration.annual3499ProductID,
        SubscriptionConfiguration.annual4999ProductID
    ]

    @MainActor
    static var referrerUsesAnnualReward: Bool {
        guard let productID = SubscriptionService.shared.activeProductIdentifier else {
            return false
        }
        return annualProductIDs.contains(productID)
    }

    @MainActor
    static var perFriendRewardLabel: String {
        referrerUsesAnnualReward ? annualRewardLabel : shortRewardLabel
    }

    @MainActor
    static var shortRewardLabel: String {
        AppCopy.t("1 mois offert", en: "1 month free")
    }

    @MainActor
    static var annualRewardLabel: String {
        AppCopy.t("1 an offert", en: "1 year free")
    }

    @MainActor
    static var headline: String {
        AppCopy.t(
            "\(perFriendRewardLabel) par ami",
            en: "\(perFriendRewardLabel) per friend"
        )
    }

    @MainActor
    static var subtitle: String {
        if referrerUsesAnnualReward {
            return AppCopy.t(
                "Ton ami s’abonne à l’annuel. S’il s’abonne, tu gagnes un an de Process.",
                en: "Your friend subscribes to yearly. If they subscribe, you earn a year of Process."
            )
        }
        return AppCopy.t(
            "Ton ami s’abonne à l’annuel. S’il s’abonne, tu gagnes un mois de Process.",
            en: "Your friend subscribes to yearly. If they subscribe, you earn a month of Process."
        )
    }

    @MainActor
    static func rewardLabel(for durationRaw: String?, status: ProcessReferralEntryStatus) -> String? {
        guard status == .accepted else { return nil }
        switch ProcessReferralRewardDuration(rawValue: durationRaw ?? "") {
        case .yearly:
            return annualRewardLabel
        case .monthly, .none:
            return shortRewardLabel
        }
    }

    @MainActor
    static func simulatedRewardLabel(friendCount: Int) -> String {
        let count = max(0, friendCount)
        guard count > 0 else {
            return AppCopy.t("0 récompense", en: "0 rewards")
        }

        if referrerUsesAnnualReward {
            switch count {
            case 1:
                return AppCopy.t("1 an offert", en: "1 year free")
            default:
                return AppCopy.t("\(count) ans offerts", en: "\(count) years free")
            }
        }

        switch count {
        case 1:
            return AppCopy.t("1 mois offert", en: "1 month free")
        default:
            return AppCopy.t("\(count) mois offerts", en: "\(count) months free")
        }
    }

    @MainActor
    static func perFriendSimulatorDetailLabel() -> String {
        AppCopy.t(
            "\(perFriendRewardLabel) · par ami abonné",
            en: "\(perFriendRewardLabel) · per subscribed friend"
        )
    }

    @MainActor
    static var opalOfferHeadline: String {
        AppCopy.t(
            "Gagne \(perFriendRewardLabel) par ami !",
            en: "Earn \(perFriendRewardLabel) per friend!"
        )
    }

    @MainActor
    static var opalZeroFriendsBody: String {
        AppCopy.t(
            "Partage ton lien — tu gagnes \(perFriendRewardLabel) à chaque ami qui s’abonne.",
            en: "Share your link — you earn \(perFriendRewardLabel) for each friend who subscribes."
        )
    }

    @MainActor
    static var opalProgressSuffix: String {
        AppCopy.t(
            "Continue à partager pour cumuler du temps Process.",
            en: "Keep sharing to stack free Process time."
        )
    }
}

struct ProcessReferralDashboardResponse: Decodable, Equatable {
    let ok: Bool
    let pendingCount: Int?
    let acceptedCount: Int?
}
