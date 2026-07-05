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
    private var persistenceGeneration: UInt64 = 0

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
                if merged.coachInsightMessage == nil {
                    merged.coachInsightMessage = existing.coachInsightMessage
                }
                if merged.coachInsightModel == nil {
                    merged.coachInsightModel = existing.coachInsightModel
                }
                byId[item.id] = FaceScanImageStore.reconcileMediaMetadata(for: merged)
            } else {
                byId[item.id] = FaceScanImageStore.reconcileMediaMetadata(for: item)
            }
        }

        history = byId.values.sorted { $0.createdAt > $1.createdAt }
        if history.count > 90 { history = Array(history.prefix(90)) }
        history = FaceWellnessScore.reconcileStoredScores(history)
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

        if let latest = latestResult,
           hasResolvableMedia(for: latest) {
            return
        }

        guard let payload = OnboardingFaceMarkersStore.loadPayload() else { return }

        let uid = userId ?? UserScopedStorage.currentUserId() ?? "local-user"
        let scanId = payload.scanId ?? "onboarding-\(uid)"

        if let existing = latestResult,
           existing.id == scanId,
           hasResolvableMedia(for: existing) {
            return
        }

        let imported = FaceScanResult(
            id: scanId,
            userId: uid,
            createdAt: payload.capturedAt ?? UnifiedUserProfile.getActualDownloadDate(),
            markers: payload.markers,
            snapshotFilename: payload.snapshotFilename,
            videoFilename: payload.videoFilename,
            source: .onboarding
        )
        let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: imported)

        if let existing = latestResult,
           existing.source == .onboarding,
           existing.id != reconciled.id,
           !hasResolvableMedia(for: existing) {
            history.removeAll { $0.id == existing.id }
            if latestResult?.id == existing.id {
                latestResult = nil
            }
        }

        push(reconciled)
    }

    /// Importe un scan onboarding stocké sous un autre uid (anonymous / local-user).
    func migrateOnboardingDataFromLikelyUsers(to userId: String) {
        OnboardingFaceMarkersStore.migrateFromLikelyUsers(to: userId)

        if let latest = latestResult,
           latest.userId == userId,
           hasResolvableMedia(for: latest) {
            return
        }

        if persistedHistoryIsEmpty(for: userId) {
            for sourceUid in UserScopedStorage.likelyUserIds(primary: userId) where sourceUid != userId {
                if let scan = loadBestPersistedScan(from: sourceUid) {
                    push(remappedOnboardingScan(scan, userId: userId))
                    return
                }
            }
        } else if let latest = latestResult,
                  latest.userId == userId,
                  !hasResolvableMedia(for: latest) {
            for sourceUid in UserScopedStorage.likelyUserIds(primary: userId) where sourceUid != userId {
                guard let scan = loadBestPersistedScan(from: sourceUid),
                      hasResolvableMedia(for: scan) else { continue }
                history.removeAll { $0.id == latest.id }
                push(remappedOnboardingScan(scan, userId: userId))
                return
            }
        }

        didImportOnboarding = false
        importOnboardingSnapshotIfNeeded()
    }

    private func remappedOnboardingScan(_ scan: FaceScanResult, userId: String) -> FaceScanResult {
        FaceScanResult(
            id: scan.id,
            userId: userId,
            createdAt: scan.createdAt,
            markers: scan.markers,
            snapshotFilename: scan.snapshotFilename,
            videoFilename: scan.videoFilename,
            claudeAnalysis: scan.claudeAnalysis,
            aiEnhanced: scan.aiEnhanced,
            coachInsightMessage: scan.coachInsightMessage,
            coachInsightModel: scan.coachInsightModel,
            source: scan.source == .daily ? .onboarding : scan.source,
            sleepHoursAtScan: scan.sleepHoursAtScan,
            hrvAtScan: scan.hrvAtScan,
            faceDayScore: scan.faceDayScore,
            relativeFaceDayScore: scan.relativeFaceDayScore,
            scanConfidence: scan.scanConfidence,
            baselineSampleCount: scan.baselineSampleCount,
            relativeSignals: scan.relativeSignals
        )
    }

    private func hasResolvableMedia(for result: FaceScanResult) -> Bool {
        let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: result)
        if FaceScanImageStore.resolvedVideoURL(for: reconciled) != nil { return true }
        if FaceScanImageStore.resolvedSnapshotFilename(for: reconciled) != nil { return true }
        return false
    }

    private func persistedHistoryIsEmpty(for userId: String) -> Bool {
        let historyKey = UserScopedStorage.key("facescan.history", userId: userId)
        let latestKey = UserScopedStorage.key("facescan.latest", userId: userId)
        return UserDefaults.standard.data(forKey: historyKey) == nil
            && UserDefaults.standard.data(forKey: latestKey) == nil
    }

    private func loadBestPersistedScan(from userId: String) -> FaceScanResult? {
        let historyKey = UserScopedStorage.key("facescan.history", userId: userId)
        let latestKey = UserScopedStorage.key("facescan.latest", userId: userId)

        if let data = UserDefaults.standard.data(forKey: historyKey),
           let items = try? JSONDecoder().decode([FaceScanResult].self, from: data) {
            let reconciled = items
                .map { FaceScanImageStore.reconcileMediaMetadata(for: $0) }
                .sorted { lhs, rhs in
                    let lhsMedia = hasResolvableMedia(for: lhs)
                    let rhsMedia = hasResolvableMedia(for: rhs)
                    if lhsMedia != rhsMedia { return lhsMedia && !rhsMedia }
                    return lhs.createdAt > rhs.createdAt
                }
            return reconciled.first
        }

        if let data = UserDefaults.standard.data(forKey: latestKey),
           let result = try? JSONDecoder().decode(FaceScanResult.self, from: data) {
            return FaceScanImageStore.reconcileMediaMetadata(for: result)
        }

        return nil
    }

    private func persist() {
        let latest = latestResult
        let historySnapshot = history
        let latestStorageKey = latestKey
        let historyStorageKey = historyKey
        persistenceGeneration &+= 1
        let generation = persistenceGeneration

        Task.detached(priority: .utility) {
            if let latest {
                await ProcessPersistenceWriter.shared.store(
                    latest,
                    forKey: latestStorageKey,
                    generation: generation
                )
            } else {
                await ProcessPersistenceWriter.shared.removeValue(
                    forKey: latestStorageKey,
                    generation: generation
                )
            }
            await ProcessPersistenceWriter.shared.store(
                historySnapshot,
                forKey: historyStorageKey,
                generation: generation
            )
        }
    }

    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let items = try? JSONDecoder().decode([FaceScanResult].self, from: data) {
            history = FaceWellnessScore.reconcileStoredScores(
                items
                    .map { FaceScanImageStore.reconcileMediaMetadata(for: $0) }
                    .sorted { $0.createdAt > $1.createdAt }
            )
            latestResult = history.first
            if history != items {
                persist()
            }
            return
        }
        if let data = UserDefaults.standard.data(forKey: latestKey),
           let result = try? JSONDecoder().decode(FaceScanResult.self, from: data) {
            let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: result)
            history = FaceWellnessScore.reconcileStoredScores([reconciled])
            latestResult = history.first
            return
        }
        latestResult = nil
        history = []
    }

    func clearForUser(userId: String?) {
        if let userId {
            let latestStorageKey = UserScopedStorage.key("facescan.latest", userId: userId)
            let historyStorageKey = UserScopedStorage.key("facescan.history", userId: userId)
            UserDefaults.standard.removeObject(forKey: latestStorageKey)
            UserDefaults.standard.removeObject(forKey: historyStorageKey)
            persistenceGeneration &+= 1
            let generation = persistenceGeneration
            Task.detached(priority: .utility) {
                await ProcessPersistenceWriter.shared.removeValue(
                    forKey: latestStorageKey,
                    generation: generation
                )
                await ProcessPersistenceWriter.shared.removeValue(
                    forKey: historyStorageKey,
                    generation: generation
                )
            }
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
