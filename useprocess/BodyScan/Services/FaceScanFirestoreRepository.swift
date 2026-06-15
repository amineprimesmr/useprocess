import FirebaseFirestore
import Foundation

@MainActor
final class FaceScanFirestoreRepository {
    static let shared = FaceScanFirestoreRepository()

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    func save(_ result: FaceScanResult) async throws {
        var cloud = result
        cloud.snapshotFilename = nil

        let ref = db.collection("users")
            .document(result.userId)
            .collection("faceScans")
            .document(result.id)

        try ref.setData(from: cloud)

        try await db.collection("users").document(result.userId).setData([
            "lastFaceScanId": result.id,
            "lastFaceScanAt": Timestamp(date: result.createdAt),
            "lastFaceDayScore": result.resolvedFaceDayScore
        ], merge: true)
    }

    func fetchHistory(userId: String, limit: Int = 90) async throws -> [FaceScanResult] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("faceScans")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: FaceScanResult.self) }
    }
}
