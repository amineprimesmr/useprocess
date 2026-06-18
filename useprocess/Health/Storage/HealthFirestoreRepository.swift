import FirebaseFirestore
import Foundation

@MainActor
final class HealthFirestoreRepository {
    static let shared = HealthFirestoreRepository()

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    func saveBaselines(_ baselines: UserHealthBaselines, userId: String) async throws {
        guard !AppSession.shared.isAccountWipeInProgress else { return }
        try db.collection("users").document(userId)
            .collection("healthBaselines").document("current")
            .setData(from: baselines, merge: true)
    }

    func saveDailySnapshot(_ snapshot: DailyHealthSnapshot, userId: String) async throws {
        guard !AppSession.shared.isAccountWipeInProgress else { return }
        try db.collection("users").document(userId)
            .collection("healthDaily").document(snapshot.dateKey)
            .setData(from: snapshot, merge: true)
    }

    func fetchBaselines(userId: String) async throws -> UserHealthBaselines? {
        let doc = try await db.collection("users").document(userId)
            .collection("healthBaselines").document("current")
            .getDocument()
        return try doc.data(as: UserHealthBaselines.self)
    }

    func fetchLatestSnapshot(userId: String) async throws -> DailyHealthSnapshot? {
        let snap = try await db.collection("users").document(userId)
            .collection("healthDaily")
            .order(by: "dateKey", descending: true)
            .limit(to: 1)
            .getDocuments()
        return try snap.documents.first?.data(as: DailyHealthSnapshot.self)
    }
}
