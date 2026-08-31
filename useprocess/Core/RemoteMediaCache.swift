import FirebaseAuth
import Foundation

/// Télécharge et met en cache localement les médias hébergés sur Firebase Storage
/// (qualité originale — les vidéos embarquées dans le bundle sont volontairement
/// compressées pour la taille de l'app, ces versions ne le sont pas).
actor RemoteMediaCache {
    static let shared = RemoteMediaCache()

    private static let bucket = "useprocess-d4385.firebasestorage.app"

    private var inFlight: [String: Task<URL, Error>] = [:]

    private var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("RemoteMedia", isDirectory: true)
    }

    /// Retourne un fichier local (téléchargé si besoin) pour un chemin Storage, ex: "media/lymph-circuit/lymph_01.mp4".
    func localURL(forStoragePath path: String) async throws -> URL {
        let destination = try cacheFileURL(for: path)

        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }

        if let existing = inFlight[path] {
            return try await existing.value
        }

        let task = Task<URL, Error> {
            defer { inFlight[path] = nil }
            return try await download(path: path, to: destination)
        }
        inFlight[path] = task
        return try await task.value
    }

    private func cacheFileURL(for path: String) throws -> URL {
        let dir = cacheDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let sanitized = path.replacingOccurrences(of: "/", with: "_")
        return dir.appendingPathComponent(sanitized)
    }

    private func download(path: String, to destination: URL) async throws -> URL {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
        guard let url = URL(string: "https://firebasestorage.googleapis.com/v0/b/\(Self.bucket)/o/\(encoded)?alt=media") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        if let token = try? await Auth.auth().currentUser?.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (tempURL, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }
}
