import Foundation

enum ProcessReferralEntryStatus: String, Codable, Equatable {
    case pending
    case accepted

    var label: String {
        switch self {
        case .pending: "En attente"
        case .accepted: "Accepté"
        }
    }
}

struct ProcessReferralEntry: Identifiable, Codable, Equatable {
    let id: String
    var displayName: String
    var invitedAt: Date
    var status: ProcessReferralEntryStatus

    var maskedName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 2 else { return trimmed }
        let first = trimmed.prefix(2)
        let last = trimmed.suffix(1)
        return "\(first)******\(last)"
    }
}

enum ProcessReferralRewardKind: String, Codable, Equatable {
    case cashEUR
    case proMonths
}

struct ProcessReferralReward: Identifiable, Equatable {
    let id: String
    let requiredReferrals: Int
    let title: String
    let kind: ProcessReferralRewardKind
    let cashAmount: Int?
    let proMonths: Int?
    let iconSystemName: String
    let accentGradient: [String]

    static let catalog: [ProcessReferralReward] = [
        ProcessReferralReward(
            id: "cash_15",
            requiredReferrals: 1,
            title: "15 € sur ton abonnement",
            kind: .cashEUR,
            cashAmount: 15,
            proMonths: nil,
            iconSystemName: "eurosign.circle.fill",
            accentGradient: ["#34C759", "#30D158"]
        ),
        ProcessReferralReward(
            id: "pro_1m",
            requiredReferrals: 3,
            title: "1 mois Process Pro gratuit",
            kind: .proMonths,
            cashAmount: nil,
            proMonths: 1,
            iconSystemName: "gift.fill",
            accentGradient: ["#5AC8FA", "#007AFF"]
        ),
        ProcessReferralReward(
            id: "pro_3m",
            requiredReferrals: 5,
            title: "3 mois Process Pro gratuit",
            kind: .proMonths,
            cashAmount: nil,
            proMonths: 3,
            iconSystemName: "crown.fill",
            accentGradient: ["#AF52DE", "#5856D6"]
        )
    ]
}

struct ProcessReferralSnapshot: Codable, Equatable {
    var referralCode: String
    var entries: [ProcessReferralEntry]
    var redeemedRewardIDs: [String]

    var acceptedCount: Int {
        entries.filter { $0.status == .accepted }.count
    }

    var redeemedRewardIDSet: Set<String> {
        Set(redeemedRewardIDs)
    }

    static let empty = ProcessReferralSnapshot(referralCode: "", entries: [], redeemedRewardIDs: [])
}
