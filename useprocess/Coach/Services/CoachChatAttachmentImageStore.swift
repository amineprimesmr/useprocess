import Foundation
import UIKit

/// Images jointes aux messages utilisateur du coach (fichiers locaux).
enum CoachChatAttachmentImageStore {
    private static let suffix = ".jpg"

    private static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("CoachChatAttachments", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        protectLocalURL(folder, isDirectory: true)
        return folder
    }

    static func filename(for messageId: UUID, index: Int) -> String {
        "\(messageId.uuidString)_\(index)\(suffix)"
    }

    @discardableResult
    static func save(images: [UIImage], messageId: UUID) -> Int {
        var saved = 0
        for (index, image) in images.enumerated() {
            guard let data = image.jpegData(compressionQuality: 0.82) else { continue }
            let url = directoryURL.appendingPathComponent(filename(for: messageId, index: index))
            do {
                try data.write(to: url, options: [.atomic])
                protectLocalURL(url, isDirectory: false)
                saved += 1
            } catch {
                continue
            }
        }
        return saved
    }

    static func load(messageId: UUID) -> [UIImage] {
        var images: [UIImage] = []
        var index = 0
        while true {
            let url = directoryURL.appendingPathComponent(filename(for: messageId, index: index))
            guard FileManager.default.isReadableFile(atPath: url.path),
                  let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else { break }
            images.append(image)
            index += 1
        }
        return images
    }

    private static func protectLocalURL(_ url: URL, isDirectory: Bool) {
        var protectedURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? protectedURL.setResourceValues(values)

        let protection: FileProtectionType = .completeUntilFirstUserAuthentication
        try? FileManager.default.setAttributes(
            [.protectionKey: protection],
            ofItemAtPath: url.path
        )
    }
}

/// Métadonnée embarquée pour retrouver les images locales d’un message.
enum CoachChatImageMessageMarker {
    private static let prefix = "[[process_chat_images:"
    private static let suffix = "]]"

    static func embed(messageId: UUID, displayText: String) -> String {
        "\(prefix)\(messageId.uuidString)\(suffix)\n\(displayText)"
    }

    static func messageId(from text: String) -> UUID? {
        guard let start = text.range(of: prefix) else { return nil }
        let after = text[start.upperBound...]
        guard let end = after.range(of: suffix) else { return nil }
        let id = String(after[..<end.lowerBound])
        return UUID(uuidString: id)
    }

    static func displayText(from text: String) -> String {
        guard let start = text.range(of: prefix) else { return text }
        guard let end = text.range(of: suffix, range: start.lowerBound..<text.endIndex) else { return text }
        let remainder = text[end.upperBound...]
        return remainder.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isPlaceholderDisplayText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "📷 Photo" { return true }
        if trimmed.hasPrefix("📷 ") && trimmed.hasSuffix(" photos") {
            let middle = trimmed.dropFirst(3).dropLast(7)
            return middle.allSatisfy(\.isNumber) && !middle.isEmpty
        }
        return false
    }
}
