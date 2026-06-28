import Foundation
import UIKit

@MainActor
@Observable
final class ProcessReferralStore {
    static let shared = ProcessReferralStore()

    private(set) var snapshot: ProcessReferralSnapshot = .empty

    private let storageKeyBase = "referral.program"

    private init() {
        reload()
    }

    func reload(username: String? = nil, userId: String? = nil) {
        let uid = userId ?? UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key(storageKeyBase, userId: uid)

        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ProcessReferralSnapshot.self, from: data) {
            snapshot = decoded
        } else {
            snapshot = ProcessReferralSnapshot(
                referralCode: makeReferralCode(username: username, userId: uid),
                entries: [],
                redeemedRewardIDs: []
            )
            persist(userId: uid)
        }

        let code = makeReferralCode(username: username, userId: uid)
        if snapshot.referralCode != code {
            snapshot.referralCode = code
            persist(userId: uid)
        }
    }

    var referralLink: String {
        "join.useprocess.xyz/\(snapshot.referralCode)"
    }

    var shareMessage: String {
        """
        Rejoins Process avec mon lien — ton 1er mois à prix réduit, et je gagne 15 € si tu t'inscris :
        \(referralLink)
        """
    }

    func redeem(reward: ProcessReferralReward) {
        guard canRedeem(reward) else { return }
        if !snapshot.redeemedRewardIDs.contains(reward.id) {
            snapshot.redeemedRewardIDs.append(reward.id)
        }
        persist()
        HapticManager.shared.notification(.success)
    }

    func canRedeem(_ reward: ProcessReferralReward) -> Bool {
        snapshot.acceptedCount >= reward.requiredReferrals
            && !snapshot.redeemedRewardIDSet.contains(reward.id)
    }

    func isRedeemed(_ reward: ProcessReferralReward) -> Bool {
        snapshot.redeemedRewardIDSet.contains(reward.id)
    }

    func progress(for reward: ProcessReferralReward) -> (current: Int, total: Int) {
        (min(snapshot.acceptedCount, reward.requiredReferrals), reward.requiredReferrals)
    }

    private func persist(userId: String? = nil) {
        let uid = userId ?? UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key(storageKeyBase, userId: uid)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func makeReferralCode(username: String?, userId: String) -> String {
        let tag = ProcessUsernameTag.normalize(username ?? "")
        if tag.count >= 4 {
            return String(tag.prefix(8)).uppercased()
        }
        let sanitized = userId
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
        return String(sanitized.prefix(6))
    }
}
