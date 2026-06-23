import Combine
import Foundation
import HealthKit

@MainActor
final class HealthManager: ObservableObject {
    static let shared = HealthManager()

    struct HealthMetrics {
        let avgHeartRate: Double
        let totalSteps: Int
        let totalFloors: Int
        let activeCalories: Double
        let exerciseTime: Double
        let distance: Double
        let standHours: Int

        init(
            avgHeartRate: Double = 0,
            totalSteps: Int = 0,
            totalFloors: Int = 0,
            activeCalories: Double = 0,
            exerciseTime: Double = 0,
            distance: Double = 0,
            standHours: Int = 0
        ) {
            self.avgHeartRate = avgHeartRate
            self.totalSteps = totalSteps
            self.totalFloors = totalFloors
            self.activeCalories = activeCalories
            self.exerciseTime = exerciseTime
            self.distance = distance
            self.standHours = standHours
        }
    }

    @Published private(set) var isAuthorized = false
    @Published private(set) var isHealthDataAvailable = false
    @Published private(set) var baselines = UserHealthBaselines()
    @Published private(set) var todaySnapshot = DailyHealthSnapshot(date: Date())
    @Published private(set) var readinessScore = 0
    @Published private(set) var readinessLabel = "—"
    @Published private(set) var readinessFactors: [String] = []
    @Published private(set) var faceDayScore: Int?
    @Published private(set) var faceDayLabel: String?
    @Published private(set) var faceCorrelations: [FaceScanCorrelationInsight] = []
    @Published private(set) var connectedSources: [String] = []
    @Published private(set) var hasAppleWatch = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncInProgress = false

    let healthStore = HKHealthStore()
    private lazy var queryService = HealthKitQueryService(store: healthStore)
    private var sleepCache: [String: (duration: Double, samples: [HKCategorySample])] = [:]
    private var observerQueries: [HKObserverQuery] = []

    private init() {
        isHealthDataAvailable = HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorizationAsync() async {
        guard isHealthDataAvailable else {
            isAuthorized = false
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: HealthKitTypes.writeTypes, read: HealthKitTypes.readTypes)
            isAuthorized = true
            await refreshConnectedSources()
            enableBackgroundObservers()
            await performFullSync()
        } catch {
            isAuthorized = false
        }
    }

    func refreshAuthorizationStatus() {
        isHealthDataAvailable = HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Sync

    func performFullSync() async {
        guard isHealthDataAvailable else { return }
        guard !AppSession.shared.isAccountWipeInProgress else { return }
        guard !syncInProgress else { return }
        syncInProgress = true
        defer {
            syncInProgress = false
            lastSyncDate = Date()
        }

        baselines = await BaselineCalculator.computeFromHealthManager(self, days: 14)
        todaySnapshot = await buildSnapshot(for: Date())
        let faceMarkers = faceMarkers(for: Date())
        let readiness = ReadinessScorer.score(
            snapshot: todaySnapshot,
            baselines: baselines,
            faceMarkers: faceMarkers,
            faceScoreOverride: faceScore(for: Date())
        )
        readinessScore = readiness.score
        readinessLabel = readiness.label
        readinessFactors = readiness.factors
        faceDayScore = readiness.faceScore
        faceDayLabel = readiness.faceLabel
        faceCorrelations = FaceScanCorrelationEngine.insights(from: FaceScanHistoryStore.shared.history)

        if AppConfiguration.firebaseConfigured, let uid = AuthUser.current?.uid {
            try? await HealthFirestoreRepository.shared.saveBaselines(baselines, userId: uid)
            try? await HealthFirestoreRepository.shared.saveDailySnapshot(todaySnapshot, userId: uid)
        }
    }

    func syncHealthDataForDate(_ date: Date) async {
        let snapshot = await buildSnapshot(for: date)
        if Calendar.current.isDateInToday(date) {
            todaySnapshot = snapshot
            let faceMarkers = faceMarkers(for: date)
            let readiness = ReadinessScorer.score(
                snapshot: snapshot,
                baselines: baselines,
                faceMarkers: faceMarkers,
                faceScoreOverride: faceScore(for: date)
            )
            readinessScore = readiness.score
            readinessLabel = readiness.label
            readinessFactors = readiness.factors
            faceDayScore = readiness.faceScore
            faceDayLabel = readiness.faceLabel
            faceCorrelations = FaceScanCorrelationEngine.insights(from: FaceScanHistoryStore.shared.history)
        }
    }

    private func faceMarkers(for date: Date) -> FaceWellnessMarkers? {
        guard let latest = FaceScanHistoryStore.shared.latestResult else { return nil }
        guard Calendar.current.isDate(latest.createdAt, inSameDayAs: date) else { return nil }
        return latest.markers
    }

    private func faceScore(for date: Date) -> Int? {
        guard let latest = FaceScanHistoryStore.shared.latestResult else { return nil }
        guard Calendar.current.isDate(latest.createdAt, inSameDayAs: date) else { return nil }
        return latest.resolvedFaceDayScore
    }

    // MARK: - API onboarding (compat)

    func getHealthMetricsForDate(_ date: Date) async -> HealthMetrics {
        let snapshot = await buildSnapshot(for: date)
        return HealthMetrics(
            avgHeartRate: snapshot.vitals.heartRate,
            totalSteps: snapshot.effort.steps,
            totalFloors: snapshot.effort.flightsClimbed,
            activeCalories: snapshot.effort.activeEnergyBurned,
            exerciseTime: snapshot.effort.exerciseMinutes,
            distance: snapshot.effort.distanceKm,
            standHours: snapshot.activity.standHours
        )
    }

    func getEffortScoreForDate(_ date: Date) async -> Double {
        let snapshot = await buildSnapshot(for: date)
        return snapshot.effort.effortScore
    }

    func getSleepDurationForDate(_ date: Date) async -> Double {
        let key = dateKey(date)
        if let cached = sleepCache[key] { return cached.duration }
        let metrics = await queryService.sleepMetrics(for: date)
        return metrics.duration
    }

    func refreshSleepDataForDate(_ date: Date) async {
        let key = dateKey(date)
        let samples = await queryService.sleepSamples(for: date)
        let metrics = await queryService.sleepMetrics(for: date)
        sleepCache[key] = (metrics.duration, samples)
    }

    func fetchSleepDataIntelligent(for date: Date) async -> [HKCategorySample] {
        let key = dateKey(date)
        if let cached = sleepCache[key] { return cached.samples }
        await refreshSleepDataForDate(date)
        return sleepCache[key]?.samples ?? []
    }

    // MARK: - Snapshot builder

    func buildSnapshot(for date: Date) async -> DailyHealthSnapshot {
        var snapshot = DailyHealthSnapshot(date: date)

        async let steps = queryService.sumQuantity(.stepCount, unit: .count(), on: date)
        async let calories = queryService.sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), on: date)
        async let floors = queryService.sumQuantity(.flightsClimbed, unit: .count(), on: date)
        async let exercise = queryService.sumQuantity(.appleExerciseTime, unit: .minute(), on: date)
        async let distance = queryService.sumQuantity(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), on: date)
        async let heartRate = queryService.averageQuantity(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()), on: date)
        async let rhr = queryService.averageQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), on: date)
        async let hrv = queryService.averageQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), on: date)
        async let spo2 = queryService.averageQuantity(.oxygenSaturation, unit: .percent(), on: date)
        async let resp = queryService.averageQuantity(.respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), on: date)
        async let stand = queryService.sumQuantity(.appleStandTime, unit: .minute(), on: date)
        async let vo2 = queryService.mostRecentQuantity(.vo2Max, unit: HKUnit.literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute())))
        async let bodyMass = queryService.mostRecentQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
        async let bodyFat = queryService.mostRecentQuantity(.bodyFatPercentage, unit: .percent())
        async let workouts = queryService.workoutCount(on: date)
        async let sleep = queryService.sleepMetrics(for: date)
        async let nutritionCal = queryService.sumQuantity(.dietaryEnergyConsumed, unit: .kilocalorie(), on: date)
        async let protein = queryService.sumQuantity(.dietaryProtein, unit: .gram(), on: date)
        async let carbs = queryService.sumQuantity(.dietaryCarbohydrates, unit: .gram(), on: date)
        async let fat = queryService.sumQuantity(.dietaryFatTotal, unit: .gram(), on: date)
        async let water = queryService.sumQuantity(.dietaryWater, unit: .liter(), on: date)

        snapshot.effort.steps = Int(await steps)
        snapshot.effort.activeEnergyBurned = await calories
        snapshot.effort.flightsClimbed = Int(await floors)
        snapshot.effort.exerciseMinutes = await exercise
        snapshot.effort.distanceKm = await distance
        snapshot.effort.workoutCount = await workouts
        snapshot.effort.effortScore = computeEffortScore(snapshot.effort)

        snapshot.vitals.heartRate = await heartRate
        snapshot.vitals.restingHeartRate = await rhr
        snapshot.vitals.hrv = await hrv
        snapshot.vitals.spo2 = await spo2 > 0 ? await spo2 * 100 : 0
        snapshot.vitals.respiratoryRate = await resp
        snapshot.vitals.bodyMass = await bodyMass
        snapshot.vitals.bodyFatPercentage = await bodyFat > 0 ? await bodyFat * 100 : 0
        applyProfileBodyFallbacks(to: &snapshot)

        snapshot.activity.standHours = Int((await stand) / 60)
        snapshot.activity.vo2Max = await vo2

        let sleepData = await sleep
        snapshot.sleep.sleepDuration = sleepData.duration
        snapshot.sleep.bedtime = sleepData.bedtime
        snapshot.sleep.wakeTime = sleepData.wake
        snapshot.sleep.deepSleepHours = sleepData.deep
        snapshot.sleep.remSleepHours = sleepData.rem
        snapshot.sleep.sleepDebt = max(0, baselines.sleepNeedHours - sleepData.duration)

        snapshot.nutrition.caloriesConsumed = await nutritionCal
        snapshot.nutrition.proteinGrams = await protein
        snapshot.nutrition.carbsGrams = await carbs
        snapshot.nutrition.fatGrams = await fat
        snapshot.nutrition.waterLiters = await water

        let faceMarkers = faceMarkers(for: date)
        let readiness = ReadinessScorer.score(
            snapshot: snapshot,
            baselines: baselines,
            faceMarkers: faceMarkers,
            faceScoreOverride: faceScore(for: date)
        )
        snapshot.recovery.recoveryScore = readiness.score
        snapshot.recovery.readinessLabel = readiness.label
        snapshot.recovery.hrv = snapshot.vitals.hrv
        snapshot.recovery.restingHeartRate = snapshot.vitals.restingHeartRate
        snapshot.recovery.sleepHours = snapshot.sleep.sleepDuration

        snapshot.connectedSources = connectedSources
        snapshot.syncedAt = Date()

        return snapshot
    }

    func refreshConnectedSources() async {
        connectedSources = await queryService.connectedSourceNames()
        hasAppleWatch = await queryService.hasAppleWatchSource()
        AppleWatchService.shared.updateFromHealthSources(connectedSources)
    }

    // MARK: - Background

    private func enableBackgroundObservers() {
        guard observerQueries.isEmpty else { return }

        for type in HealthKitTypes.observerTypes {
            healthStore.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
                Task { @MainActor in
                    await self?.performFullSync()
                    completion()
                }
            }
            healthStore.execute(query)
            observerQueries.append(query)
        }
    }

    // MARK: - Helpers

    /// Complète le snapshot avec le profil (onboarding) quand HealthKit n'a pas encore de mesure.
    private func applyProfileBodyFallbacks(to snapshot: inout DailyHealthSnapshot) {
        guard let profile = UnifiedProfileService.shared.currentProfile else { return }
        if snapshot.vitals.bodyMass <= 0, profile.weight > 0 {
            snapshot.vitals.bodyMass = profile.weight
        }
    }

    private func computeEffortScore(_ effort: DailyEffortData) -> Double {
        let stepScore = min(30, Double(effort.steps) / 10_000 * 30)
        let calScore = min(30, effort.activeEnergyBurned / 500 * 30)
        let exScore = min(25, effort.exerciseMinutes / 30 * 25)
        let woScore = min(15, Double(effort.workoutCount) * 7.5)
        return min(100, stepScore + calScore + exScore + woScore)
    }

    private func dateKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
