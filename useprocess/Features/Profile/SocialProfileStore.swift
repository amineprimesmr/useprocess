import Foundation
import SwiftUI

struct SocialProfilePin: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var title: String
    var subtitle: String?
    var emoji: String
    var createdAt: Date
}

struct SocialProfile: Codable, Equatable {
    var displayName: String
    var username: String
    var bio: String?
    var education: String?
    var interests: String?
    var interestTags: [String]
    var isPrivate: Bool
    var pins: [SocialProfilePin]

    static func from(unified: UnifiedUserProfile) -> SocialProfile {
        let handle = unified.username
            ?? unified.email?
                .components(separatedBy: "@")
                .first?
                .lowercased()
                .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
            ?? unified.firstName.lowercased()

        return SocialProfile(
            displayName: [unified.firstName, unified.lastName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "),
            username: handle.isEmpty ? "process" : handle,
            bio: nil,
            education: nil,
            interests: nil,
            interestTags: [],
            isPrivate: false,
            pins: []
        )
    }

    static var guest: SocialProfile {
        SocialProfile(
            displayName: "Process",
            username: "process",
            bio: nil,
            education: nil,
            interests: nil,
            interestTags: [],
            isPrivate: false,
            pins: []
        )
    }
}

@Observable
@MainActor
final class SocialProfileStore {
    static let shared = SocialProfileStore()

    private(set) var profile: SocialProfile?
    private var activeUserID: String?

    private init() {}

    func bind(unified: UnifiedUserProfile?) {
        guard let unified else {
            activeUserID = nil
            profile = nil
            return
        }
        if activeUserID == unified.userId, profile != nil {
            syncFromUnified(unified)
            return
        }
        activeUserID = unified.userId
        load(for: unified)
        migrateFromLegacyLocalUserIfNeeded(to: unified.userId)
        syncFromUnified(unified)
    }

    func syncFromUnified(_ unified: UnifiedUserProfile) {
        activeUserID = unified.userId

        var current: SocialProfile
        if let persisted = loadPersistedProfile(userId: unified.userId) {
            current = persisted
        } else if let inMemory = profile {
            current = inMemory
        } else {
            current = .from(unified: unified)
        }

        let mergedName = [unified.firstName, unified.lastName]
            .map { $0?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !mergedName.isEmpty {
            current.displayName = mergedName
        }
        if let username = unified.username?.trimmingCharacters(in: .whitespacesAndNewlines),
           !username.isEmpty {
            current.username = username
        }
        profile = current
        persist()
    }

    func resetForUser(userId: String) {
        profile = nil
        activeUserID = nil
        UserDefaults.standard.removeObject(forKey: Self.storageKey(for: userId))
    }

    func load(for unified: UnifiedUserProfile) {
        activeUserID = unified.userId
        if let saved = loadPersistedProfile(userId: unified.userId) {
            profile = saved
        } else {
            profile = .from(unified: unified)
            persist()
        }
    }

    func update(_ transform: (inout SocialProfile) -> Void) {
        guard var current = profile else { return }
        transform(&current)
        profile = current
        persist()
    }

    func addPin(title: String, emoji: String = "📌") {
        let pin = SocialProfilePin(
            id: UUID().uuidString,
            title: title,
            subtitle: nil,
            emoji: emoji,
            createdAt: Date()
        )
        update { $0.pins.insert(pin, at: 0) }
    }

    func removePin(_ id: String) {
        update { $0.pins.removeAll { $0.id == id } }
    }

    var shareText: String {
        guard let profile else { return "Process" }
        let tag = ProcessUsernameTag.display(profile.username)
        if tag.isEmpty {
            return AppCopy.t(
                "Profil Process — \(profile.displayName)",
                en: "Process Profile — \(profile.displayName)"
            )
        }
        return AppCopy.t(
            "Profil Process — \(profile.displayName) (\(tag))",
            en: "Process Profile — \(profile.displayName) (\(tag))"
        )
    }

    private func loadPersistedProfile(userId: String) -> SocialProfile? {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey(for: userId)) else {
            return nil
        }
        return try? JSONDecoder().decode(SocialProfile.self, from: data)
    }

    /// Reprend les métadonnées enregistrées sous `local-user` avant connexion Apple/Firebase.
    private func migrateFromLegacyLocalUserIfNeeded(to userId: String) {
        guard userId != "local-user", userId != "anonymous" else { return }
        guard let legacy = loadPersistedProfile(userId: "local-user") else { return }

        var current = profile ?? legacy
        var didChange = false

        if current.pins.isEmpty, !legacy.pins.isEmpty {
            current.pins = legacy.pins
            didChange = true
        }
        if current.bio == nil, legacy.bio != nil {
            current.bio = legacy.bio
            didChange = true
        }
        if current.education == nil, legacy.education != nil {
            current.education = legacy.education
            didChange = true
        }
        if current.interests == nil, legacy.interests != nil {
            current.interests = legacy.interests
            didChange = true
        }
        if current.interestTags.isEmpty, !legacy.interestTags.isEmpty {
            current.interestTags = legacy.interestTags
            didChange = true
        }

        if didChange {
            profile = current
            persist()
        }

        UserDefaults.standard.removeObject(forKey: Self.storageKey(for: "local-user"))
    }

    private func persist() {
        guard let userID = activeUserID, let profile else { return }
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.storageKey(for: userID))
        }
    }

    private static func storageKey(for userID: String) -> String {
        UserScopedStorage.key("socialProfile", userId: userID)
    }
}
