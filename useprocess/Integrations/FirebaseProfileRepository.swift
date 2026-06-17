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

    func deleteProfile(userId: String) async throws {
        try await db.collection(collection).document(userId).delete()
    }

    /// Efface le document utilisateur et les sous-collections connues.
    func deleteAllRemoteUserData(userId: String) async throws {
        try await deleteDocuments(
            in: db.collection(collection).document(userId).collection("faceScans")
        )

        let coachThreads = try await db.collection(collection)
            .document(userId)
            .collection("coachThreads")
            .getDocuments()

        for thread in coachThreads.documents {
            try await deleteDocuments(in: thread.reference.collection("messages"))
            try await thread.reference.delete()
        }

        try await deleteProfile(userId: userId)
    }

    private func deleteDocuments(in collection: CollectionReference) async throws {
        let snapshot = try await collection.getDocuments()
        guard !snapshot.documents.isEmpty else { return }

        let batch = db.batch()
        snapshot.documents.forEach { batch.deleteDocument($0.reference) }
        try await batch.commit()
    }

    func saveProfile(_ profile: UnifiedUserProfile) async throws {
        var updated = profile
        updated.updateLastUpdated()
        try db.collection(collection).document(profile.userId).setData(from: updated, merge: true)
    }
}
