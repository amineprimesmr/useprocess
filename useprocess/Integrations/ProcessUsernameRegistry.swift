import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class ProcessUsernameRegistry {
    static let shared = ProcessUsernameRegistry()

    private let collection = "usernames"
    private var db: Firestore { Firestore.firestore() }

    private init() {}

    private var isCloudReady: Bool {
        FirebaseBootstrap.isConfigured
            && Auth.auth().currentUser != nil
    }

    func isAvailable(_ rawTag: String, for userId: String) async throws -> Bool {
        let tag = ProcessUsernameTag.normalize(rawTag)
        guard !tag.isEmpty else { return false }

        guard isCloudReady else { return true }

        let snapshot = try await db.collection(collection).document(tag).getDocument()
        guard snapshot.exists else { return true }
        return snapshot.data()?["userId"] as? String == userId
    }

    func suggestAvailableUsername(base: String, userId: String) async throws -> String {
        let seedBase = ProcessUsernameTag.normalize(base)
        let seed = seedBase.isEmpty ? "user" : seedBase

        if (try? ProcessUsernameTag.validate(seed)) != nil,
           try await isAvailable(seed, for: userId) {
            return seed
        }

        for index in 1...999 {
            let candidate = "\(seed)\(index)"
            guard candidate.count <= ProcessUsernameTag.maxLength else { break }
            if (try? ProcessUsernameTag.validate(candidate)) != nil,
               try await isAvailable(candidate, for: userId) {
                return candidate
            }
        }

        return "user\(UUID().uuidString.prefix(6).lowercased())"
    }

    func claimUsername(
        tag rawTag: String,
        userId: String,
        displayName: String,
        previousTag: String?
    ) async throws {
        let tag = ProcessUsernameTag.normalize(rawTag)
        try ProcessUsernameTag.validate(tag)

        guard isCloudReady else { return }

        let newRef = db.collection(collection).document(tag)
        let oldTag = previousTag.map(ProcessUsernameTag.normalize).flatMap { $0.isEmpty ? nil : $0 }
        let database = db

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.runTransaction({ transaction, errorPointer in
                do {
                    let existing = try transaction.getDocument(newRef)
                    if existing.exists,
                       existing.data()?["userId"] as? String != userId {
                        throw ProcessUsernameError.taken
                    }

                    if let oldTag, oldTag != tag {
                        let oldRef = database.collection(self.collection).document(oldTag)
                        let oldSnapshot = try transaction.getDocument(oldRef)
                        if oldSnapshot.exists,
                           oldSnapshot.data()?["userId"] as? String == userId {
                            transaction.deleteDocument(oldRef)
                        }
                    }

                    transaction.setData([
                        "userId": userId,
                        "displayName": displayName,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: newRef, merge: true)

                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }, completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    func lookup(tag rawTag: String) async throws -> ProcessPublicUserTag {
        let tag = ProcessUsernameTag.normalize(rawTag)
        try ProcessUsernameTag.validate(tag)

        guard isCloudReady else {
            throw ProcessUsernameError.cloudUnavailable("Connexion requise pour rechercher un tag.")
        }

        let snapshot = try await db.collection(collection).document(tag).getDocument()
        guard snapshot.exists,
              let data = snapshot.data(),
              let userId = data["userId"] as? String else {
            throw ProcessUsernameError.notFound
        }

        let displayName = (data["displayName"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? tag

        return ProcessPublicUserTag(tag: tag, userId: userId, displayName: displayName)
    }

    func releaseUsername(_ rawTag: String?, userId: String) async throws {
        guard let rawTag else { return }
        let tag = ProcessUsernameTag.normalize(rawTag)
        guard !tag.isEmpty, isCloudReady else { return }

        let ref = db.collection(collection).document(tag)
        let snapshot = try await ref.getDocument()
        guard snapshot.exists,
              snapshot.data()?["userId"] as? String == userId else { return }
        try await ref.delete()
    }
}

@MainActor
enum ProcessUsernameProvisioner {
    private static var lastAttemptByUserID: [String: Date] = [:]
    private static let retryInterval: TimeInterval = 60

    static func ensureUsernameClaimed(
        profile: UnifiedUserProfile,
        profileService: UnifiedProfileService
    ) async {
        guard profile.userId != "local-user", profile.userId != "anonymous" else { return }
        let now = Date()
        if let lastAttempt = lastAttemptByUserID[profile.userId],
           now.timeIntervalSince(lastAttempt) < retryInterval {
            return
        }
        lastAttemptByUserID[profile.userId] = now

        let current = profile.username.map(ProcessUsernameTag.normalize) ?? ""
        let displayName = profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if current.isEmpty {
                let suggested = try await ProcessUsernameRegistry.shared.suggestAvailableUsername(
                    base: displayName.isEmpty ? "user" : displayName,
                    userId: profile.userId
                )
                try await profileService.updateUsername(suggested, displayName: displayName)
                return
            }

            try ProcessUsernameTag.validate(current)
            let available = try await ProcessUsernameRegistry.shared.isAvailable(current, for: profile.userId)
            if available {
                try await ProcessUsernameRegistry.shared.claimUsername(
                    tag: current,
                    userId: profile.userId,
                    displayName: displayName.isEmpty ? current : displayName,
                    previousTag: nil
                )
            } else {
                let suggested = try await ProcessUsernameRegistry.shared.suggestAvailableUsername(
                    base: current,
                    userId: profile.userId
                )
                try await profileService.updateUsername(suggested, displayName: displayName)
            }
        } catch {
            #if DEBUG
            print("[ProcessUsername] ensure failed: \(error.localizedDescription)")
            #endif
        }
    }
}
