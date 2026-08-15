import Foundation

@MainActor
@Observable
final class ProcessPlanProgressStore {
    static let shared = ProcessPlanProgressStore()

    private(set) var snapshot: PlanProgressSnapshot = .empty
    private var state = ProcessPlanProgressState()
    private var persistenceGeneration: UInt64 = 0

    private init() {
        state = ProcessPlanProgressEngine.sanitizeState(loadState() ?? ProcessPlanProgressState())
    }

    // MARK: - Public

    func reload(plan: FaceOriginPlan? = nil) {
        state = ProcessPlanProgressEngine.sanitizeState(loadState() ?? ProcessPlanProgressState())
        guard let plan else {
            snapshot = .empty
            return
        }
        refreshSnapshot(
            plan: plan,
            trajectory: ProcessDebloatTrajectoryStore.shared.snapshot,
            consecutiveMisses: ProcessDebloatTrajectoryStore.shared.consecutiveMissCount
        )
    }

    func sync(
        plan: FaceOriginPlan?,
        trajectory: DebloatTrajectorySnapshot,
        records: [DebloatDayRecord],
        consecutiveMisses: Int,
        consecutiveCardioMisses: Int = 0
    ) {
        state = ProcessPlanProgressEngine.evaluateDurationAdjustment(
            state: state,
            plan: plan,
            trajectory: trajectory,
            records: records,
            consecutiveMisses: consecutiveMisses,
            consecutiveCardioMisses: consecutiveCardioMisses,
            earlyCompletion: false
        )
        state = ProcessPlanProgressEngine.sanitizeState(state)
        persist()
        refreshSnapshot(plan: plan, trajectory: trajectory, consecutiveMisses: consecutiveMisses)
    }

    func evaluateAfterScan(plan: FaceOriginPlan?, latestScan: FaceScanResult) {
        let earlyCompletion = plan.map {
            PlanRecalibrationService.checkEarlyCompletion(plan: $0, latestScan: latestScan)
        } ?? false

        let trajectory = ProcessDebloatTrajectoryStore.shared.snapshot
        state = ProcessPlanProgressEngine.evaluateDurationAdjustment(
            state: state,
            plan: plan,
            trajectory: trajectory,
            records: Array(ProcessDebloatTrajectoryStore.shared.allRecordsByDay.values),
            consecutiveMisses: ProcessDebloatTrajectoryStore.shared.consecutiveMissCount,
            consecutiveCardioMisses: ProcessDebloatTrajectoryStore.shared.consecutiveCardioMissCount,
            earlyCompletion: earlyCompletion
        )
        state = ProcessPlanProgressEngine.sanitizeState(state)
        persist()
        refreshSnapshot(
            plan: plan,
            trajectory: trajectory,
            consecutiveMisses: ProcessDebloatTrajectoryStore.shared.consecutiveMissCount
        )
    }

    var recentEvolutionEvents: [PlanDurationEvolutionEvent] {
        state.events
    }

    // MARK: - Private

    private func refreshSnapshot(
        plan: FaceOriginPlan?,
        trajectory: DebloatTrajectorySnapshot,
        consecutiveMisses: Int
    ) {
        let latestEvent = state.events.first
        let updated = ProcessPlanProgressEngine.snapshot(
            plan: plan,
            trajectory: trajectory,
            adjustmentDays: state.adjustmentDays,
            latestEvent: latestEvent,
            profile: UnifiedProfileService.shared.currentProfile,
            now: ProcessCreatorModeStore.shared.effectiveNow
        )

        if snapshot != updated {
            snapshot = updated
        }

        if state.schemaVersion < 2 {
            state = ProcessPlanProgressEngine.sanitizeState(state)
            persist()
        }

        _ = consecutiveMisses
    }

    private func persist() {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.plan.progress", userId: uid)
        let stateSnapshot = state
        persistenceGeneration &+= 1
        let generation = persistenceGeneration
        Task.detached(priority: .utility) {
            await ProcessPersistenceWriter.shared.store(
                stateSnapshot,
                forKey: key,
                generation: generation
            )
        }
    }

    private func loadState() -> ProcessPlanProgressState? {
        let uid = UserScopedStorage.currentUserId() ?? "local-user"
        let key = UserScopedStorage.key("process.plan.progress", userId: uid)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ProcessPlanProgressState.self, from: data)
    }
}
