import Foundation
import HealthKit

final class HealthKitQueryService {

    private let store: HKHealthStore
    private let calendar = Calendar.current

    init(store: HKHealthStore) {
        self.store = store
    }

    // MARK: - Day range

    func dayRange(for date: Date) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return (start, end)
    }

    // MARK: - Statistics (sum / average)

    func sumQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, on date: Date) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let range = dayRange(for: date)
        return await statisticsValue(
            type: type,
            unit: unit,
            start: range.start,
            end: range.end,
            options: .cumulativeSum
        )
    }

    func averageQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, on date: Date) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let range = dayRange(for: date)
        return await statisticsValue(
            type: type,
            unit: unit,
            start: range.start,
            end: range.end,
            options: .discreteAverage
        )
    }

    func mostRecentQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, withinDays: Int = 30) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -withinDays, to: end) ?? end

        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: HKQuery.predicateForSamples(withStart: start, end: end),
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func statisticsValue(
        type: HKQuantityType,
        unit: HKUnit,
        start: Date,
        end: Date,
        options: HKStatisticsOptions
    ) async -> Double {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: options) { _, stats, _ in
                if options.contains(.cumulativeSum), let sum = stats?.sumQuantity() {
                    continuation.resume(returning: sum.doubleValue(for: unit))
                } else if options.contains(.discreteAverage), let avg = stats?.averageQuantity() {
                    continuation.resume(returning: avg.doubleValue(for: unit))
                } else {
                    continuation.resume(returning: 0)
                }
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep

    func sleepSamples(for date: Date) async -> [HKCategorySample] {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }

        // Fenêtre sommeil : veille 18h → jour cible 14h
        let dayStart = calendar.startOfDay(for: date)
        let windowStart = calendar.date(byAdding: .hour, value: -6, to: dayStart) ?? dayStart
        let windowEnd = calendar.date(byAdding: .hour, value: 14, to: dayStart) ?? dayStart

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
    }

    func sleepMetrics(for date: Date) async -> (duration: Double, bedtime: Date?, wake: Date?, deep: Double, rem: Double) {
        let samples = await sleepSamples(for: date)
        guard !samples.isEmpty else { return (0, nil, nil, 0, 0) }

        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]

        var totalAsleep: TimeInterval = 0
        var deep: TimeInterval = 0
        var rem: TimeInterval = 0
        var asleepSamples: [HKCategorySample] = []

        for sample in samples where asleepValues.contains(sample.value) {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            totalAsleep += duration
            asleepSamples.append(sample)
            if sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue {
                deep += duration
            } else if sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                rem += duration
            }
        }

        let bedtime = asleepSamples.min(by: { $0.startDate < $1.startDate })?.startDate
        let wake = asleepSamples.max(by: { $0.endDate < $1.endDate })?.endDate

        return (
            totalAsleep / 3600,
            bedtime,
            wake,
            deep / 3600,
            rem / 3600
        )
    }

    // MARK: - Workouts

    func workoutCount(on date: Date) async -> Int {
        let range = dayRange(for: date)
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples?.count ?? 0)
            }
            store.execute(query)
        }
    }

    // MARK: - Sources

    func connectedSourceNames() async -> [String] {
        let probeTypes: [HKSampleType?] = [
            HKQuantityType.quantityType(forIdentifier: .stepCount),
            HKQuantityType.quantityType(forIdentifier: .heartRate),
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.workoutType()
        ]

        var names = Set<String>()

        await withTaskGroup(of: Set<String>.self) { group in
            for sampleType in probeTypes.compactMap({ $0 }) {
                group.addTask { [store] in
                    await withCheckedContinuation { continuation in
                        let query = HKSourceQuery(sampleType: sampleType, samplePredicate: nil) { _, sources, _ in
                            let cleaned = (sources ?? []).map(\.name).filter { !$0.isEmpty }
                            continuation.resume(returning: Set(cleaned))
                        }
                        store.execute(query)
                    }
                }
            }

            for await batch in group {
                names.formUnion(batch)
            }
        }

        return names.sorted()
    }

    func hasAppleWatchSource() async -> Bool {
        let sources = await connectedSourceNames()
        return sources.contains { $0.localizedCaseInsensitiveContains("watch") }
    }

    // MARK: - Historique pour baselines

    func historicalDailyValues(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        days: Int,
        options: HKStatisticsOptions
    ) async -> [Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }

        var values: [Double] = []
        let today = Date()

        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let range = dayRange(for: date)
            let value = await statisticsValue(type: type, unit: unit, start: range.start, end: range.end, options: options)
            if value > 0 { values.append(value) }
        }

        return values
    }

    func historicalSleepDurations(days: Int) async -> [Double] {
        let today = Date()
        var values: [Double] = []

        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let metrics = await sleepMetrics(for: date)
            if metrics.duration > 0 { values.append(metrics.duration) }
        }

        return values
    }
}
