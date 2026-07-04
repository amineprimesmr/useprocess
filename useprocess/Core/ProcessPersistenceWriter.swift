import Foundation

/// File d'écriture sérialisée hors du MainActor.
///
/// Les gros modèles sont encodés ici afin que la sauvegarde locale ne bloque
/// jamais une frame SwiftUI. `generation` empêche une tâche plus ancienne,
/// arrivée en retard sur l'acteur, d'écraser une version récente.
actor ProcessPersistenceWriter {
    static let shared = ProcessPersistenceWriter()

    private var latestGenerationByKey: [String: UInt64] = [:]

    func store<T: Encodable & Sendable>(
        _ value: T,
        forKey key: String,
        generation: UInt64
    ) {
        let latest = latestGenerationByKey[key] ?? 0
        guard generation >= latest else { return }
        latestGenerationByKey[key] = generation

        autoreleasepool {
            guard let data = try? JSONEncoder().encode(value) else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func removeValue(forKey key: String, generation: UInt64) {
        let latest = latestGenerationByKey[key] ?? 0
        guard generation >= latest else { return }
        latestGenerationByKey[key] = generation
        UserDefaults.standard.removeObject(forKey: key)
    }
}
