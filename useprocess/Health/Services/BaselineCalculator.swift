import Foundation

enum BaselineCalculator {

    static func compute(from snapshots: [DailyHealthSnapshot], queryDays: Int) -> UserHealthBaselines {
        guard !snapshots.isEmpty else { return UserHealthBaselines() }

        let hrvValues = snapshots.map(\.vitals.hrv).filter { $0 > 0 }
        let rhrValues = snapshots.map(\.vitals.restingHeartRate).filter { $0 > 0 }
        let sleepValues = snapshots.map(\.sleep.sleepDuration).filter { $0 > 0 }
        let stepValues = snapshots.map { Double($0.effort.steps) }.filter { $0 > 0 }
        let calorieValues = snapshots.map(\.effort.activeEnergyBurned).filter { $0 > 0 }
        let exerciseValues = snapshots.map(\.effort.exerciseMinutes).filter { $0 > 0 }

        let hrvStats = stats(hrvValues)
        let rhrStats = stats(rhrValues)
        let sleepStats = stats(sleepValues)

        let avgExercise = exerciseValues.isEmpty ? 30 : exerciseValues.reduce(0, +) / Double(exerciseValues.count)
        let effortCapacity = min(25, max(8, avgExercise * 0.5 + (stepValues.isEmpty ? 0 : stats(stepValues).mean / 1000)))

        return UserHealthBaselines(
            hrv: hrvStats.mean,
            hrvStd: hrvStats.std,
            restingHeartRate: rhrStats.mean,
            restingHeartRateStd: rhrStats.std,
            sleepNeedHours: sleepStats.mean > 0 ? sleepStats.mean : 8,
            sleepNeedStd: sleepStats.std,
            effortCapacity: effortCapacity,
            avgDailySteps: stats(stepValues).mean,
            avgActiveCalories: stats(calorieValues).mean,
            calculatedAt: Date(),
            daysOfData: min(queryDays, snapshots.count)
        )
    }

    static func computeFromHealthManager(_ manager: HealthManager, days: Int = 14) async -> UserHealthBaselines {
        var snapshots: [DailyHealthSnapshot] = []
        let calendar = Calendar.current
        let today = Date()

        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let snapshot = await manager.buildSnapshot(for: date)
            if snapshot.effort.steps > 0 || snapshot.sleep.sleepDuration > 0 || snapshot.vitals.hrv > 0 {
                snapshots.append(snapshot)
            }
        }

        return compute(from: snapshots, queryDays: days)
    }

    private static func stats(_ values: [Double]) -> (mean: Double, std: Double) {
        guard !values.isEmpty else { return (0, 0) }
        let mean = values.reduce(0, +) / Double(values.count)
        guard values.count > 1 else { return (mean, 0) }
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count - 1)
        return (mean, sqrt(variance))
    }
}
