import Foundation
import SwiftUI
import UIKit

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
    var profilePhotoFilename: String?
    var coverPhotoFilename: String?
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
            profilePhotoFilename: nil,
            coverPhotoFilename: nil,
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
            profilePhotoFilename: nil,
            coverPhotoFilename: nil,
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
    private let fileManager = FileManager.default

    private var photosDirectory: URL {
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("ProcessProfilePhotos", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

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
        if let cover = profile?.coverPhotoFilename {
            deleteFile(cover)
        }
        if let avatar = profile?.profilePhotoFilename, avatar != profile?.coverPhotoFilename {
            deleteFile(avatar)
        }
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

    func applyPhotos(_ image: UIImage) {
        guard let filename = saveImage(image, prefix: "cover") else { return }
        let previous = profile?.coverPhotoFilename
        update {
            $0.profilePhotoFilename = filename
            $0.coverPhotoFilename = filename
        }
        if let previous, previous != filename {
            deleteFile(previous)
        }
    }

    func removeAllPhotos() {
        if let name = profile?.coverPhotoFilename { deleteFile(name) }
        update {
            $0.profilePhotoFilename = nil
            $0.coverPhotoFilename = nil
        }
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

    var coverPhoto: UIImage? { image(for: profile?.coverPhotoFilename) }
    var profilePhoto: UIImage? { image(for: profile?.profilePhotoFilename) }

    var hasCoverPhoto: Bool {
        profile?.coverPhotoFilename != nil && coverPhoto != nil
    }

    var hasProfilePhoto: Bool {
        profile?.profilePhotoFilename != nil && profilePhoto != nil
    }

    var shareText: String {
        guard let profile else { return "Process" }
        return "Profil Process — \(profile.displayName) (@\(profile.username))"
    }

    private func image(for filename: String?) -> UIImage? {
        guard let filename else { return nil }
        let url = photosDirectory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private func loadPersistedProfile(userId: String) -> SocialProfile? {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey(for: userId)) else {
            return nil
        }
        return try? JSONDecoder().decode(SocialProfile.self, from: data)
    }

    /// Reprend une photo enregistrée sous `local-user` avant connexion Apple/Firebase.
    private func migrateFromLegacyLocalUserIfNeeded(to userId: String) {
        guard userId != "local-user", userId != "anonymous" else { return }
        guard let legacy = loadPersistedProfile(userId: "local-user") else { return }

        var current = profile ?? legacy
        var didChange = false

        if current.profilePhotoFilename == nil, legacy.profilePhotoFilename != nil {
            current.profilePhotoFilename = legacy.profilePhotoFilename
            current.coverPhotoFilename = legacy.coverPhotoFilename
            didChange = true
        }
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

    private enum PhotoStorage {
        /// Cover hero pleine largeur (Retina 3× ~430 pt → ~1290 px, marge pour zoom/crop).
        static let coverMaxPixelDimension: CGFloat = 2560
        static let jpegQuality: CGFloat = 0.92
    }

    private func saveImage(_ image: UIImage, prefix: String) -> String? {
        let prepared = image.resizedForProfile(maxPixelDimension: PhotoStorage.coverMaxPixelDimension)
        guard let data = prepared.jpegData(compressionQuality: PhotoStorage.jpegQuality) else { return nil }
        let filename = "\(prefix)-\(UUID().uuidString).jpg"
        let url = photosDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    private func deleteFile(_ filename: String) {
        let url = photosDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: url)
    }
}

private extension UIImage {
    /// Downscale only if larger than `maxPixelDimension` (pixels), preserving native scale.
    func resizedForProfile(maxPixelDimension: CGFloat) -> UIImage {
        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale
        let maxPixelSide = max(pixelWidth, pixelHeight)
        guard maxPixelSide > maxPixelDimension else { return self }

        let ratio = maxPixelDimension / maxPixelSide
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
