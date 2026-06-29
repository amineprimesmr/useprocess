import Foundation
import UIKit

enum FaceScanImageStore {

    private static let snapshotSuffix = "_face.jpg"
    private static let videoSuffix = "_face.mp4"

    private static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("FaceScans", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        protectLocalURL(folder, isDirectory: true)
        return folder
    }

    static func snapshotFilename(for scanId: String) -> String {
        "\(scanId)\(snapshotSuffix)"
    }

    static func videoFilename(for scanId: String) -> String {
        "\(scanId)\(videoSuffix)"
    }

    static func save(image: UIImage, scanId: String) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.84) else { return nil }
        let name = snapshotFilename(for: scanId)
        let url = directoryURL.appendingPathComponent(name)
        do {
            try data.write(to: url, options: [.atomic])
            protectLocalURL(url, isDirectory: false)
            return name
        } catch {
            return nil
        }
    }

    static func load(filename: String) -> UIImage? {
        let url = directoryURL.appendingPathComponent(filename)
        guard isReadableFile(at: url),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func videoURL(for scanId: String) -> URL {
        directoryURL.appendingPathComponent(videoFilename(for: scanId))
    }

    static func saveVideo(from sourceURL: URL, scanId: String) -> String? {
        let name = videoFilename(for: scanId)
        let destination = directoryURL.appendingPathComponent(name)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: sourceURL, to: destination)
            protectLocalURL(destination, isDirectory: false)
            return name
        } catch {
            return nil
        }
    }

    static func videoFileURL(filename: String) -> URL {
        directoryURL.appendingPathComponent(filename)
    }

    static func finalizeRecordedVideo(at url: URL) {
        protectLocalURL(url, isDirectory: false)
    }

    static func resolvedVideoURL(for result: FaceScanResult) -> URL? {
        let candidates = videoFilenameCandidates(for: result)
        for filename in candidates {
            let url = videoFileURL(filename: filename)
            if isReadableFile(at: url) { return url }
        }
        return nil
    }

    static func resolvedSnapshotFilename(for result: FaceScanResult) -> String? {
        let candidates = snapshotFilenameCandidates(for: result)
        for filename in candidates where isReadableFile(at: directoryURL.appendingPathComponent(filename)) {
            return filename
        }
        return nil
    }

    static func reconcileMediaMetadata(for result: FaceScanResult) -> FaceScanResult {
        var reconciled = result
        if let snapshot = resolvedSnapshotFilename(for: result) {
            reconciled.snapshotFilename = snapshot
        }
        if let videoName = videoFilenameCandidates(for: reconciled).first(where: {
            isReadableFile(at: videoFileURL(filename: $0))
        }) {
            reconciled.videoFilename = videoName
        }
        return reconciled
    }

    /// Assouplit la protection des fichiers déjà enregistrés (migration one-shot).
    static func migrateExistingMediaProtectionIfNeeded() {
        let folder = directoryURL
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return }
        for name in files where name.hasSuffix(snapshotSuffix) || name.hasSuffix(videoSuffix) {
            protectLocalURL(folder.appendingPathComponent(name), isDirectory: false)
        }
    }

    /// Supprime toutes les photos et vidéos de scan visage stockées localement.
    static func deleteAllStoredMedia() {
        let folder = directoryURL
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return }
        for name in files where name.hasSuffix(snapshotSuffix) || name.hasSuffix(videoSuffix) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }

    static func deleteMedia(forScanId scanId: String) {
        let folder = directoryURL
        for suffix in [snapshotSuffix, videoSuffix] {
            let url = folder.appendingPathComponent("\(scanId)\(suffix)")
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Supprime les médias dont l’identifiant n’est plus dans l’historique (rétention 90 scans).
    static func deleteMedia(exceptScanIds keptIds: Set<String>) {
        let folder = directoryURL
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return }
        for name in files where name.hasSuffix(snapshotSuffix) || name.hasSuffix(videoSuffix) {
            let scanId = name
                .replacingOccurrences(of: snapshotSuffix, with: "")
                .replacingOccurrences(of: videoSuffix, with: "")
            if !keptIds.contains(scanId) {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
            }
        }
    }

    private static func snapshotFilenameCandidates(for result: FaceScanResult) -> [String] {
        var names: [String] = []
        if let stored = result.snapshotFilename { names.append(stored) }
        names.append(snapshotFilename(for: result.id))
        return Array(Set(names))
    }

    private static func videoFilenameCandidates(for result: FaceScanResult) -> [String] {
        var names: [String] = []
        if let stored = result.videoFilename { names.append(stored) }
        names.append(videoFilename(for: result.id))
        return Array(Set(names))
    }

    private static func isReadableFile(at url: URL) -> Bool {
        guard FileManager.default.isReadableFile(atPath: url.path),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true else { return false }
        if url.pathExtension.lowercased() == "mp4" {
            return (values.fileSize ?? 0) > 1_024
        }
        return (values.fileSize ?? 0) > 0
    }

    private static func protectLocalURL(_ url: URL, isDirectory: Bool) {
        var protectedURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? protectedURL.setResourceValues(values)

        // Même niveau que le dossier : accessible après le premier déverrouillage,
        // pas bloqué dès que l’iPhone se verrouille (cause fréquente d’aperçus vides).
        let protection: FileProtectionType = .completeUntilFirstUserAuthentication
        try? FileManager.default.setAttributes(
            [.protectionKey: protection],
            ofItemAtPath: url.path
        )
    }
}
