import Foundation
import UIKit

enum FaceScanImageStore {

    private static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("FaceScans", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    static func save(image: UIImage, scanId: String) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.84) else { return nil }
        let name = "\(scanId)_face.jpg"
        let url = directoryURL.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func load(filename: String) -> UIImage? {
        let url = directoryURL.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func videoURL(for scanId: String) -> URL {
        directoryURL.appendingPathComponent("\(scanId)_face.mp4")
    }

    static func saveVideo(from sourceURL: URL, scanId: String) -> String? {
        let name = "\(scanId)_face.mp4"
        let destination = directoryURL.appendingPathComponent(name)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: sourceURL, to: destination)
            return name
        } catch {
            return nil
        }
    }

    static func videoFileURL(filename: String) -> URL {
        directoryURL.appendingPathComponent(filename)
    }

    /// Supprime toutes les photos et vidéos de scan visage stockées localement.
    static func deleteAllStoredMedia() {
        let folder = directoryURL
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return }
        for name in files where name.hasSuffix("_face.jpg") || name.hasSuffix("_face.mp4") {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }

    static func deleteMedia(forScanId scanId: String) {
        let folder = directoryURL
        for suffix in ["_face.jpg", "_face.mp4"] {
            let url = folder.appendingPathComponent("\(scanId)\(suffix)")
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Supprime les médias dont l’identifiant n’est plus dans l’historique (rétention 90 scans).
    static func deleteMedia(exceptScanIds keptIds: Set<String>) {
        let folder = directoryURL
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return }
        for name in files where name.hasSuffix("_face.jpg") || name.hasSuffix("_face.mp4") {
            let scanId = name
                .replacingOccurrences(of: "_face.jpg", with: "")
                .replacingOccurrences(of: "_face.mp4", with: "")
            if !keptIds.contains(scanId) {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
            }
        }
    }
}
