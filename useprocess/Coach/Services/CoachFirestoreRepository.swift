import FirebaseFirestore
import Foundation

struct CoachFirestoreMessage: Codable {
    let id: String
    let role: String
    let text: String
    let createdAt: Date
    let modelUsed: String?

    init(from message: CoachMessage) {
        id = message.id.uuidString
        role = message.role.rawValue
        text = message.text
        createdAt = message.createdAt
        modelUsed = message.modelUsed
    }

    func toCoachMessage() -> CoachMessage? {
        guard let role = CoachMessageRole(rawValue: role) else { return nil }
        return CoachMessage(
            id: UUID(uuidString: id) ?? UUID(),
            role: role,
            text: text,
            createdAt: createdAt,
            modelUsed: modelUsed
        )
    }
}

@MainActor
final class CoachFirestoreRepository {
    static let shared = CoachFirestoreRepository()

    private var db: Firestore { Firestore.firestore() }
    private let threadDocId = "default"

    private init() {}

    func fetchThread(userId: String) async throws -> CoachChatThread {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("coachThreads")
            .document(threadDocId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .limit(to: 200)
            .getDocuments()

        let messages = snapshot.documents.compactMap { doc -> CoachMessage? in
            try? doc.data(as: CoachFirestoreMessage.self).toCoachMessage()
        }

        return CoachChatThread(messages: messages, updatedAt: Date())
    }

    func appendMessage(userId: String, message: CoachMessage) async throws {
        let ref = db.collection("users")
            .document(userId)
            .collection("coachThreads")
            .document(threadDocId)
            .collection("messages")
            .document(message.id.uuidString)

        try ref.setData(from: CoachFirestoreMessage(from: message))

        try await db.collection("users")
            .document(userId)
            .collection("coachThreads")
            .document(threadDocId)
            .setData([
                "updatedAt": Timestamp(date: Date()),
                "messageCount": FieldValue.increment(Int64(1))
            ], merge: true)
    }

    func replaceThread(userId: String, thread: CoachChatThread) async throws {
        let batch = db.batch()
        let messagesRef = db.collection("users")
            .document(userId)
            .collection("coachThreads")
            .document(threadDocId)
            .collection("messages")

        let existing = try await messagesRef.getDocuments()
        existing.documents.forEach { batch.deleteDocument($0.reference) }

        for message in thread.messages {
            let doc = messagesRef.document(message.id.uuidString)
            try batch.setData(from: CoachFirestoreMessage(from: message), forDocument: doc)
        }

        let threadRef = db.collection("users")
            .document(userId)
            .collection("coachThreads")
            .document(threadDocId)

        batch.setData([
            "updatedAt": Timestamp(date: thread.updatedAt),
            "messageCount": thread.messages.count
        ], forDocument: threadRef, merge: true)

        try await batch.commit()
    }

    func resetThread(userId: String) async throws {
        let messagesRef = db.collection("users")
            .document(userId)
            .collection("coachThreads")
            .document(threadDocId)
            .collection("messages")

        let snapshot = try await messagesRef.getDocuments()
        let batch = db.batch()
        snapshot.documents.forEach { batch.deleteDocument($0.reference) }
        try await batch.commit()
    }
}
