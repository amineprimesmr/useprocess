import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseProfileRepository {
    static let shared = FirebaseProfileRepository()

    private let collection = "users"
    private var db: Firestore { Firestore.firestore() }

    private init() {}

    func loadProfile(userId: String) async throws -> UnifiedUserProfile? {
        let snapshot = try await db.collection(collection).document(userId).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: UnifiedUserProfile.self)
    }

    func saveProfile(_ profile: UnifiedUserProfile) async throws {
        var updated = profile
        updated.updateLastUpdated()
        try db.collection(collection).document(profile.userId).setData(from: updated, merge: true)
    }
}
