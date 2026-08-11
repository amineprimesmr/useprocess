import Foundation
import UIKit

@MainActor
@Observable
final class ProcessReferralStore {
    static let shared = ProcessReferralStore()

    private(set) var snapshot: ProcessReferralSnapshot = .empty

    private let storageKeyBase = "referral.program"
    private var observingUserId: String?

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
                redeemedRewardIDs: [],
                pendingCount: 0,
                acceptedCount: 0
            )
            persist(userId: uid)
        }

        let code = makeReferralCode(username: username, userId: uid)
        if snapshot.referralCode != code {
            snapshot.referralCode = code
            persist(userId: uid)
        }

        startObservingIfNeeded(userId: uid, displayName: username)
    }

    func syncRemote(displayName: String?) async {
        let code = snapshot.referralCode
        guard !code.isEmpty else { return }
        await ReferralService.shared.syncReferrerProgram(
            referralCode: code,
            displayName: displayName
        )
    }

    var referralLinkURL: URL {
        ProcessReferralLink.brandedShortURL(code: snapshot.referralCode)
    }

    var referralLink: String {
        referralLinkURL.absoluteString
    }

    var displayReferralCode: String {
        ProcessReferralLink.displayCode(from: snapshot.referralCode)
    }

    var shareMessage: String {
        """
        \(AppCopy.t("Télécharge Process avec mon lien :", en: "Download Process with my link:"))
        \(referralLink)

        \(AppCopy.t("Mon code parrainage : \(displayReferralCode)", en: "My referral code: \(displayReferralCode)"))
        \(ProcessReferralProgramTerms.inviteeRewardSummary)
        """
    }

    var copyPayload: String {
        shareMessage
    }

    func copyToPasteboard() {
        UIPasteboard.general.string = copyPayload
    }

    func stopObserving() {
        ProcessReferralFirestoreRepository.shared.stopObserving()
        observingUserId = nil
    }

    private func startObservingIfNeeded(userId: String, displayName: String?) {
        guard userId != "local-user", FirebaseBootstrap.isConfigured else { return }
        guard observingUserId != userId else { return }

        observingUserId = userId
        ProcessReferralFirestoreRepository.shared.observeInvites(userId: userId) { [weak self] entries in
            guard let self else { return }
            snapshot.entries = entries
            snapshot.pendingCount = entries.filter { $0.status == .pending }.count
            snapshot.acceptedCount = entries.filter { $0.status == .accepted }.count
            persist(userId: userId)
        }

        Task {
            await syncRemote(displayName: displayName)
        }
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
        let prefix: String
        if tag.count >= 4 {
            prefix = String(tag.prefix(4)).uppercased()
        } else if tag.count >= 2 {
            prefix = String(tag.prefix(2)).uppercased() + "PR"
        } else {
            prefix = "PROC"
        }

        let sanitized = userId
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }

        let suffixSource = sanitized.isEmpty ? "7K2Q9" : sanitized
        let suffix = String(suffixSource.suffix(5))
        return "\(prefix)-\(suffix)"
    }
}
