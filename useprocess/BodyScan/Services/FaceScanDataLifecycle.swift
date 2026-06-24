import Foundation

/// Purge, rétention 90 scans, révocation consentement — aligné politique §3.4.
@MainActor
enum FaceScanDataLifecycle {
    static func enforceRetention(for store: FaceScanHistoryStore) {
        let keptIds = Set(store.history.map(\.id))
        FaceScanImageStore.deleteMedia(exceptScanIds: keptIds)
        Task { @MainActor in
            await pruneCloud(keeping: keptIds)
        }
    }

    static func purgeAllForCurrentUser() async {
        let uid = UserScopedStorage.currentUserId()
        FaceScanHistoryStore.shared.clearForUser(userId: uid)
        FaceScanImageStore.deleteAllStoredMedia()
        OnboardingFaceMarkersStore.clear()
        if let uid, AppConfiguration.firebaseConfigured {
            try? await FaceScanFirestoreRepository.shared.deleteAll(userId: uid)
        }
    }

    private static func pruneCloud(keeping keptIds: Set<String>) async {
        guard AppConfiguration.firebaseConfigured,
              let uid = UserScopedStorage.currentUserId() else { return }
        try? await FaceScanFirestoreRepository.shared.prune(userId: uid, keeping: keptIds)
    }
}
