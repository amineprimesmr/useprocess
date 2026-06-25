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
        let userRef = db.collection(collection).document(userId)

        if let profile = try await loadProfile(userId: userId) {
            try await ProcessUsernameRegistry.shared.releaseUsername(profile.username, userId: userId)
        }

        try await deleteDocuments(in: userRef.collection("faceScans"))
        try await deleteDocuments(in: userRef.collection("scans"))
        try await deleteDocuments(in: userRef.collection("healthDaily"))
        try await deleteDocuments(in: userRef.collection("welcomePlan"))

        let healthBaselines = userRef.collection("healthBaselines")
        try await deleteDocuments(in: healthBaselines)

        let coachMeta = userRef.collection("coachMeta")
        try await deleteDocuments(in: coachMeta)

        let coachThreads = try await userRef.collection("coachThreads").getDocuments()
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
