import Foundation

/// Vidéos démo du circuit lymphatique (PiP) — `lymph_01`…`03`, `lymph_05`…`07`.
enum LymphCircuitVideoCatalog {
    /// Qualité originale (non compressée) hébergée sur Firebase Storage — cache disque local après 1er accès.
    static func remoteDemoURL(for step: FaceMorningRoutineCatalog.Step) async -> URL? {
        try? await RemoteMediaCache.shared.localURL(
            forStoragePath: "media/lymph-circuit/\(step.demoVideoResourceName).mp4"
        )
    }

    static func demoURL(for step: FaceMorningRoutineCatalog.Step) -> URL? {
        url(for: step.demoVideoResourceName)
    }

    static func url(for resourceName: String) -> URL? {
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "mp4") {
            return url
        }
        if let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "mp4",
            subdirectory: "Resources/LymphCircuit"
        ) {
            return url
        }
        if let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "mp4",
            subdirectory: "LymphCircuit"
        ) {
            return url
        }
        return nil
    }
}
