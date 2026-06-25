import Foundation

@MainActor
@Observable
final class FaceScanHistoryStore {
    static let shared = FaceScanHistoryStore()

    private(set) var latestResult: FaceScanResult?
    private(set) var history: [FaceScanResult] = []

    private var userId: String?
    private var didImportOnboarding = false
    private var didLoadLocal = false
    private var remoteSyncTask: Task<Void, Never>?

    private var latestKey: String {
        UserScopedStorage.key("facescan.latest", userId: userId)
    }

    private var historyKey: String {
        UserScopedStorage.key("facescan.history", userId: userId)
    }

    private init() {
        reloadForUser(userId: UserScopedStorage.currentUserId())
    }

    func reloadForUser(userId newUserId: String?) {
        guard !didLoadLocal || userId != newUserId else { return }

        self.userId = newUserId
        didLoadLocal = true
        didImportOnboarding = false
        FaceScanImageStore.migrateExistingMediaProtectionIfNeeded()
        loadFromDisk()
        importOnboardingSnapshotIfNeeded()

        remoteSyncTask?.cancel()
        remoteSyncTask = Task { await syncFromRemote() }
    }

    func push(_ result: FaceScanResult) {
        let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: result)
        latestResult = reconciled
        history.removeAll { $0.id == reconciled.id }
        history.insert(reconciled, at: 0)
        if history.count > 90 { history = Array(history.prefix(90)) }
        persist()
        uploadToCloud(reconciled)
        FaceScanDataLifecycle.enforceRetention(for: self)
    }

    func update(_ result: FaceScanResult) {
        let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: result)
        if latestResult?.id == reconciled.id {
            latestResult = reconciled
        }
        if let index = history.firstIndex(where: { $0.id == reconciled.id }) {
            history[index] = reconciled
        }
        persist()
        uploadToCloud(reconciled)
    }

    func syncFromRemote() async {
        guard !AppSession.shared.isAccountWipeInProgress else { return }
        guard ProcessPrivacyConsentStore.shared.canCaptureFaceScan else { return }
        guard AppConfiguration.firebaseConfigured,
              let uid = userId ?? AuthUser.current?.uid else { return }

        guard let remote = try? await FaceScanFirestoreRepository.shared.fetchHistory(userId: uid, limit: 90) else {
            return
        }
        guard !Task.isCancelled else { return }
        mergeRemote(remote)
    }

    private func mergeRemote(_ remote: [FaceScanResult]) {
        var byId = Dictionary(uniqueKeysWithValues: history.map { ($0.id, $0) })

        for item in remote {
            if let existing = byId[item.id] {
                var merged = item.createdAt >= existing.createdAt ? item : existing
                if merged.snapshotFilename == nil {
                    merged.snapshotFilename = existing.snapshotFilename
                }
                if merged.videoFilename == nil {
                    merged.videoFilename = existing.videoFilename
                }
                if !merged.aiEnhanced, existing.aiEnhanced {
                    merged.claudeAnalysis = existing.claudeAnalysis
                    merged.aiEnhanced = true
                }
                byId[item.id] = FaceScanImageStore.reconcileMediaMetadata(for: merged)
            } else {
                byId[item.id] = FaceScanImageStore.reconcileMediaMetadata(for: item)
            }
        }

        history = byId.values.sorted { $0.createdAt > $1.createdAt }
        if history.count > 90 { history = Array(history.prefix(90)) }
        latestResult = history.first
        persist()
        FaceScanDataLifecycle.enforceRetention(for: self)
    }

    private func uploadToCloud(_ result: FaceScanResult) {
        guard AppConfiguration.firebaseConfigured else { return }
        guard ProcessPrivacyConsentStore.shared.canCaptureFaceScan else { return }
        Task {
            try? await FaceScanFirestoreRepository.shared.save(result)
        }
    }

    var previousResult: FaceScanResult? {
        guard history.count > 1 else { return nil }
        return history[1]
    }

    var daysSinceLastScan: Int? {
        guard let latest = latestResult else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: latest.createdAt), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return max(0, days)
    }

    var daysUntilNextScan: Int? {
        guard let latest = latestResult else { return 0 }
        return FaceScanCadence.daysUntilNextScan(since: latest.createdAt)
    }

    var isScanDue: Bool {
        FaceScanCadence.isScanDue(since: latestResult?.createdAt)
    }

    /// Nombre de jours consécutifs avec scan (rythme quotidien).
    var streakDays: Int {
        guard !history.isEmpty else { return 0 }
        let calendar = Calendar.current
        let sorted = history.sorted { $0.createdAt > $1.createdAt }
        var streak = 0
        var windowEnd = calendar.startOfDay(for: Date())

        for scan in sorted {
            let scanDay = calendar.startOfDay(for: scan.createdAt)
            let daysBeforeWindow = calendar.dateComponents([.day], from: scanDay, to: windowEnd).day ?? 0
            guard daysBeforeWindow <= FaceScanCadence.intervalDays else { break }
            streak += 1
            windowEnd = calendar.date(byAdding: .day, value: -FaceScanCadence.intervalDays, to: scanDay) ?? scanDay
        }
        return streak
    }

    func recentResults(limit: Int = 7) -> [FaceScanResult] {
        Array(history.prefix(limit))
    }

    private func importOnboardingSnapshotIfNeeded() {
        guard !didImportOnboarding else { return }
        didImportOnboarding = true
        guard history.isEmpty, let markers = OnboardingFaceMarkersStore.load() else { return }

        let uid = userId ?? UserScopedStorage.currentUserId() ?? "local-user"
        let imported = FaceScanResult(
            id: "onboarding-\(uid)",
            userId: uid,
            createdAt: UnifiedUserProfile.getActualDownloadDate(),
            markers: markers,
            source: .onboarding
        )
        push(imported)
    }

    private func persist() {
        if let latest = latestResult, let data = try? JSONEncoder().encode(latest) {
            UserDefaults.standard.set(data, forKey: latestKey)
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let items = try? JSONDecoder().decode([FaceScanResult].self, from: data) {
            history = items
                .map { FaceScanImageStore.reconcileMediaMetadata(for: $0) }
                .sorted { $0.createdAt > $1.createdAt }
            latestResult = history.first
            return
        }
        if let data = UserDefaults.standard.data(forKey: latestKey),
           let result = try? JSONDecoder().decode(FaceScanResult.self, from: data) {
            let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: result)
            latestResult = reconciled
            history = [reconciled]
            return
        }
        latestResult = nil
        history = []
    }

    func clearForUser(userId: String?) {
        if let userId {
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("facescan.latest", userId: userId))
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key("facescan.history", userId: userId))
        }
        remoteSyncTask?.cancel()
        remoteSyncTask = nil
        self.userId = userId
        didImportOnboarding = false
        didLoadLocal = false
        latestResult = nil
        history = []
    }

    /// Remplace l’historique (rétention / purge).
    func replaceHistory(_ items: [FaceScanResult]) {
        history = items.sorted { $0.createdAt > $1.createdAt }
        latestResult = history.first
        persist()
    }
}
