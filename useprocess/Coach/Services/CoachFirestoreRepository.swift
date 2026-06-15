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

struct CoachFirestoreThreadMeta: Codable {
    var title: String?
    var updatedAt: Date?
    var messageCount: Int?
}

@MainActor
final class CoachFirestoreRepository {
    static let shared = CoachFirestoreRepository()

    private var db: Firestore { Firestore.firestore() }
    private let legacyThreadDocId = "default"

    private init() {}

    private func threadRef(userId: String, conversationId: String) -> DocumentReference {
        db.collection("users")
            .document(userId)
            .collection("coachThreads")
            .document(conversationId)
    }

    func fetchThread(userId: String, conversationId: String) async throws -> CoachChatThread {
        let snapshot = try await threadRef(userId: userId, conversationId: conversationId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .limit(to: 200)
            .getDocuments()

        let messages = snapshot.documents.compactMap { doc -> CoachMessage? in
            try? doc.data(as: CoachFirestoreMessage.self).toCoachMessage()
        }

        let meta = try? await threadRef(userId: userId, conversationId: conversationId)
            .getDocument()
            .data(as: CoachFirestoreThreadMeta.self)

        return CoachChatThread(
            messages: messages,
            updatedAt: meta?.updatedAt ?? messages.last?.createdAt ?? Date()
        )
    }

    func fetchThreadWithLegacyFallback(userId: String, conversationId: String) async throws -> CoachChatThread {
        let thread = try await fetchThread(userId: userId, conversationId: conversationId)
        guard thread.messages.isEmpty, conversationId != legacyThreadDocId else { return thread }
        return try await fetchThread(userId: userId, conversationId: legacyThreadDocId)
    }

    func appendMessage(userId: String, conversationId: String, message: CoachMessage, title: String?) async throws {
        let ref = threadRef(userId: userId, conversationId: conversationId)
            .collection("messages")
            .document(message.id.uuidString)

        try ref.setData(from: CoachFirestoreMessage(from: message))

        var meta: [String: Any] = [
            "updatedAt": Timestamp(date: Date()),
            "messageCount": FieldValue.increment(Int64(1))
        ]
        if let title, !title.isEmpty {
            meta["title"] = title
        }

        try await threadRef(userId: userId, conversationId: conversationId).setData(meta, merge: true)
    }

    func replaceThread(
        userId: String,
        conversationId: String,
        thread: CoachChatThread,
        title: String?
    ) async throws {
        let batch = db.batch()
        let messagesRef = threadRef(userId: userId, conversationId: conversationId).collection("messages")

        let existing = try await messagesRef.getDocuments()
        existing.documents.forEach { batch.deleteDocument($0.reference) }

        for message in thread.messages {
            let doc = messagesRef.document(message.id.uuidString)
            try batch.setData(from: CoachFirestoreMessage(from: message), forDocument: doc)
        }

        var meta: [String: Any] = [
            "updatedAt": Timestamp(date: thread.updatedAt),
            "messageCount": thread.messages.count
        ]
        if let title, !title.isEmpty {
            meta["title"] = title
        }

        batch.setData(meta, forDocument: threadRef(userId: userId, conversationId: conversationId), merge: true)
        try await batch.commit()
    }

    func deleteThread(userId: String, conversationId: String) async throws {
        let messagesRef = threadRef(userId: userId, conversationId: conversationId).collection("messages")
        let snapshot = try await messagesRef.getDocuments()
        let batch = db.batch()
        snapshot.documents.forEach { batch.deleteDocument($0.reference) }
        batch.deleteDocument(threadRef(userId: userId, conversationId: conversationId))
        try await batch.commit()
    }
}
