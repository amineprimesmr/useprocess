import Foundation

/// Purge, rétention 90 scans, révocation consentement — aligné politique §3.4.
enum FaceScanDataLifecycle {
    @MainActor
    static func enforceRetention(for store: FaceScanHistoryStore = .shared) {
        let keptIds = Set(store.history.map(\.id))
        FaceScanImageStore.deleteMedia(exceptScanIds: keptIds)
        Task { await pruneCloud(keeping: keptIds) }
    }

    @MainActor
    static func purgeAllForCurrentUser() async {
        let uid = UserScopedStorage.currentUserId()
        FaceScanHistoryStore.shared.clearForUser(userId: uid)
        FaceScanImageStore.deleteAllStoredMedia()
        OnboardingFaceMarkersStore.clear()
        if let uid, AppConfiguration.firebaseConfigured {
            try? await FaceScanFirestoreRepository.shared.deleteAll(userId: uid)
        }
    }

    @MainActor
    private static func pruneCloud(keeping keptIds: Set<String>) async {
        guard AppConfiguration.firebaseConfigured,
              let uid = UserScopedStorage.currentUserId() else { return }
        try? await FaceScanFirestoreRepository.shared.prune(userId: uid, keeping: keptIds)
    }
}
