import Foundation

/// Marqueurs visage + mesh 3D capturés pendant l'onboarding (stockage local, scopé utilisateur).
enum OnboardingFaceMarkersStore {
    private static let legacyMarkersKey = "useprocess.onboarding.face_markers"
    private static let legacyMeshKey = "useprocess.onboarding.face_mesh"
    private static let legacyPayloadKey = "useprocess.onboarding.face_scan_payload"

    private static func markersKey(for userId: String?) -> String {
        UserScopedStorage.key("onboarding.face_markers", userId: userId ?? "anonymous")
    }

    private static func meshKey(for userId: String?) -> String {
        UserScopedStorage.key("onboarding.face_mesh", userId: userId ?? "anonymous")
    }

    private static func payloadKey(for userId: String?) -> String {
        UserScopedStorage.key("onboarding.face_scan_payload", userId: userId ?? "anonymous")
    }

    private static var currentUserId: String? {
        UserScopedStorage.currentUserId()
    }

    static func save(markers: FaceWellnessMarkers, mesh: FaceMesh3DData) {
        let uid = currentUserId
        let payload = OnboardingFaceScanPayload(markers: markers, mesh: mesh)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: payloadKey(for: uid))
        saveMarkersOnly(markers, userId: uid)
        if let meshData = try? JSONEncoder().encode(mesh) {
            UserDefaults.standard.set(meshData, forKey: meshKey(for: uid))
        }
    }

    static func save(_ markers: FaceWellnessMarkers) {
        saveMarkersOnly(markers, userId: currentUserId)
    }

    private static func saveMarkersOnly(_ markers: FaceWellnessMarkers, userId: String?) {
        guard let data = try? JSONEncoder().encode(markers) else { return }
        UserDefaults.standard.set(data, forKey: markersKey(for: userId))
    }

    static func loadPayload() -> OnboardingFaceScanPayload? {
        migrateLegacyIfNeeded()
        let uid = currentUserId
        if let data = UserDefaults.standard.data(forKey: payloadKey(for: uid)),
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
        migrateLegacyIfNeeded()
        guard let data = UserDefaults.standard.data(forKey: meshKey(for: currentUserId)),
              let mesh = try? JSONDecoder().decode(FaceMesh3DData.self, from: data),
              mesh.isValid else {
            return nil
        }
        return mesh
    }

    private static func loadMarkers() -> FaceWellnessMarkers? {
        migrateLegacyIfNeeded()
        guard let data = UserDefaults.standard.data(forKey: markersKey(for: currentUserId)),
              let markers = try? JSONDecoder().decode(FaceWellnessMarkers.self, from: data) else {
            return nil
        }
        return markers
    }

    static func clear() {
        let uid = currentUserId
        UserDefaults.standard.removeObject(forKey: markersKey(for: uid))
        UserDefaults.standard.removeObject(forKey: meshKey(for: uid))
        UserDefaults.standard.removeObject(forKey: payloadKey(for: uid))
        UserDefaults.standard.removeObject(forKey: legacyMarkersKey)
        UserDefaults.standard.removeObject(forKey: legacyMeshKey)
        UserDefaults.standard.removeObject(forKey: legacyPayloadKey)
    }

    private static func migrateLegacyIfNeeded() {
        let uid = currentUserId
        guard UserDefaults.standard.data(forKey: payloadKey(for: uid)) == nil,
              let legacy = UserDefaults.standard.data(forKey: legacyPayloadKey) else { return }
        UserDefaults.standard.set(legacy, forKey: payloadKey(for: uid))
        if let markers = UserDefaults.standard.data(forKey: legacyMarkersKey) {
            UserDefaults.standard.set(markers, forKey: markersKey(for: uid))
        }
        if let mesh = UserDefaults.standard.data(forKey: legacyMeshKey) {
            UserDefaults.standard.set(mesh, forKey: meshKey(for: uid))
        }
        UserDefaults.standard.removeObject(forKey: legacyMarkersKey)
        UserDefaults.standard.removeObject(forKey: legacyMeshKey)
        UserDefaults.standard.removeObject(forKey: legacyPayloadKey)
    }
}
