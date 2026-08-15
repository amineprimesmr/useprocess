import FirebaseFirestore
import Foundation

@MainActor
final class DebloatTrajectoryFirestoreRepository {
    static let shared = DebloatTrajectoryFirestoreRepository()

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    func saveDay(_ record: DebloatDayRecord) async {
        guard let userId = UserScopedStorage.currentUserId(), !userId.isEmpty else { return }
        let ref = db.collection("users")
            .document(userId)
            .collection("debloatTrajectory")
            .document(record.dayKey)

        do {
            try ref.setData(from: record, merge: true)
            try await db.collection("users").document(userId).setData([
                "lastDebloatTrajectoryDay": record.dayKey,
                "lastDebloatCompositeScore": record.compositeScore,
                "lastDebloatVerdict": record.verdict.rawValue,
                "currentDebloatStreak": ProcessStreakStore.shared.displayStreak
            ], merge: true)
        } catch {
            #if DEBUG
            print("[DebloatTrajectoryFirestore] save failed: \(error)")
            #endif
        }
    }

    func fetchHistory(userId: String, limit: Int = 90) async throws -> [DebloatDayRecord] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("debloatTrajectory")
            .order(by: "dayKey", descending: true)
            .limit(to: limit)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: DebloatDayRecord.self) }
    }
}
