import FirebaseFirestore
import Foundation

@MainActor
final class ProcessReferralFirestoreRepository {
    static let shared = ProcessReferralFirestoreRepository()

    private var listener: ListenerRegistration?
    private var db: Firestore { Firestore.firestore() }

    private init() {}

    func observeInvites(
        userId: String,
        onChange: @escaping ([ProcessReferralEntry]) -> Void
    ) {
        listener?.remove()
        listener = db
            .collection("users")
            .document(userId)
            .collection("referralInvites")
            .order(by: "invitedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    #if DEBUG
                    print("[ReferralFirestore] listen error: \(error.localizedDescription)")
                    #endif
                    return
                }

                let entries = snapshot?.documents.compactMap(Self.mapEntry) ?? []
                Task { @MainActor in
                    onChange(entries)
                }
            }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
    }

    private static func mapEntry(_ document: QueryDocumentSnapshot) -> ProcessReferralEntry? {
        let data = document.data()
        guard let displayName = data["displayName"] as? String else { return nil }

        let statusRaw = data["status"] as? String ?? ProcessReferralEntryStatus.pending.rawValue
        let status = ProcessReferralEntryStatus(rawValue: statusRaw) ?? .pending

        let invitedAt: Date
        if let timestamp = data["invitedAt"] as? Timestamp {
            invitedAt = timestamp.dateValue()
        } else {
            invitedAt = Date()
        }

        let rewardLabel = data["referrerRewardDuration"] as? String

        return ProcessReferralEntry(
            id: document.documentID,
            displayName: displayName,
            invitedAt: invitedAt,
            status: status,
            rewardLabel: ProcessReferralProgramTerms.rewardLabel(for: rewardLabel, status: status)
        )
    }
}
