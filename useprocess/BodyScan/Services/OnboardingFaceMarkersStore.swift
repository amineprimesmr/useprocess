import Foundation

/// Marqueurs visage + mesh 3D capturés pendant l'onboarding.
enum OnboardingFaceMarkersStore {
    private static let markersKey = "useprocess.onboarding.face_markers"
    private static let meshKey = "useprocess.onboarding.face_mesh"
    private static let payloadKey = "useprocess.onboarding.face_scan_payload"

    static func save(markers: FaceWellnessMarkers, mesh: FaceMesh3DData) {
        let payload = OnboardingFaceScanPayload(markers: markers, mesh: mesh)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: payloadKey)
        saveMarkersOnly(markers)
        if let meshData = try? JSONEncoder().encode(mesh) {
            UserDefaults.standard.set(meshData, forKey: meshKey)
        }
    }

    static func save(_ markers: FaceWellnessMarkers) {
        saveMarkersOnly(markers)
    }

    private static func saveMarkersOnly(_ markers: FaceWellnessMarkers) {
        guard let data = try? JSONEncoder().encode(markers) else { return }
        UserDefaults.standard.set(data, forKey: markersKey)
    }

    static func loadPayload() -> OnboardingFaceScanPayload? {
        if let data = UserDefaults.standard.data(forKey: payloadKey),
           let payload = try? JSONDecoder().decode(OnboardingFaceScanPayload.self, from: data) {
            return payload
        }
        guard let markers = loadMarkers() else { return nil }
        return OnboardingFaceScanPayload(markers: markers, mesh: loadMesh() ?? .empty)
    }

    static func load() -> FaceWellnessMarkers? {
        loadPayload()?.markers ?? loadMarkers()
    }

    static func loadMesh() -> FaceMesh3DData? {
        if let payload = loadPayload(), payload.mesh.isValid {
            return payload.mesh
        }
        guard let data = UserDefaults.standard.data(forKey: meshKey),
              let mesh = try? JSONDecoder().decode(FaceMesh3DData.self, from: data),
              mesh.isValid else {
            return nil
        }
        return mesh
    }

    private static func loadMarkers() -> FaceWellnessMarkers? {
        guard let data = UserDefaults.standard.data(forKey: markersKey),
              let markers = try? JSONDecoder().decode(FaceWellnessMarkers.self, from: data) else {
            return nil
        }
        return markers
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: markersKey)
        UserDefaults.standard.removeObject(forKey: meshKey)
        UserDefaults.standard.removeObject(forKey: payloadKey)
    }
}
