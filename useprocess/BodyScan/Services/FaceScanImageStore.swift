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
}
