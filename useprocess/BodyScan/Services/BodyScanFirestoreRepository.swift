import FirebaseFirestore
import Foundation

@MainActor
final class BodyScanFirestoreRepository {
    static let shared = BodyScanFirestoreRepository()

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    func save(_ result: BodyScanResult) async throws {
        let ref = db.collection("users")
            .document(result.userId)
            .collection("scans")
            .document(result.id)

        try ref.setData(from: result)

        try await db.collection("users").document(result.userId).setData([
            "lastBodyScanId": result.id,
            "lastBodyScanAt": Timestamp(date: result.createdAt),
            "lastPostureScore": result.postureScore
        ], merge: true)
    }

    func fetchLatest(userId: String) async throws -> BodyScanResult? {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("scans")
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()

        return try snapshot.documents.first?.data(as: BodyScanResult.self)
    }

    func fetchHistory(userId: String, limit: Int = 12) async throws -> [BodyScanResult] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("scans")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: BodyScanResult.self) }
    }
}
