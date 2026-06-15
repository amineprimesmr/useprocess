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
            if profile == nil {
                profile = .guest
            }
            activeUserID = nil
            return
        }
        guard activeUserID != unified.userId || profile == nil else { return }
        activeUserID = unified.userId
        load(for: unified)
    }

    func load(for unified: UnifiedUserProfile) {
        let key = Self.storageKey(for: unified.userId)
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(SocialProfile.self, from: data) {
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
        update {
            $0.profilePhotoFilename = filename
            $0.coverPhotoFilename = filename
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

    private func persist() {
        guard let userID = activeUserID, let profile else { return }
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.storageKey(for: userID))
        }
    }

    private static func storageKey(for userID: String) -> String {
        UserScopedStorage.key("socialProfile", userId: userID)
    }

    private func saveImage(_ image: UIImage, prefix: String) -> String? {
        let resized = image.resizedForProfile(maxDimension: 1400)
        guard let data = resized.jpegData(compressionQuality: 0.82) else { return nil }
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
    func resizedForProfile(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
