import Foundation

// MARK: - Données quotidiennes (compat onboarding)

struct DailyRecoveryData: Codable {
    var recoveryScore: Int = 0
    var hrv: Double = 0
    var restingHeartRate: Double = 0
    var sleepHours: Double = 0
    var readinessLabel: String = "—"
}

struct DailyEffortData: Codable {
    var effortScore: Double = 0
    var steps: Int = 0
    var activeEnergyBurned: Double = 0
    var flightsClimbed: Int = 0
    var exerciseMinutes: Double = 0
    var distanceKm: Double = 0
    var workoutCount: Int = 0
}

struct DailySleepData: Codable {
    var sleepDuration: Double = 0
    var bedtime: Date?
    var wakeTime: Date?
    var deepSleepHours: Double = 0
    var remSleepHours: Double = 0
    var sleepDebt: Double = 0
}

struct DailyActivityData: Codable {
    var standHours: Int = 0
    var vo2Max: Double = 0
    var walkingSteadiness: Double = 0
}

struct DailyHealthMetricsData: Codable {
    var heartRate: Double = 0
    var hrv: Double = 0
    var restingHeartRate: Double = 0
    var spo2: Double = 0
    var respiratoryRate: Double = 0
    var bodyMass: Double = 0
    var bodyFatPercentage: Double = 0
}

struct DailyNutritionData: Codable {
    var caloriesConsumed: Double = 0
    var proteinGrams: Double = 0
    var carbsGrams: Double = 0
    var fatGrams: Double = 0
    var waterLiters: Double = 0
}

// MARK: - Snapshot complet

struct DailyHealthSnapshot: Codable, Identifiable {
    var id: String { dateKey }
    let dateKey: String
    let date: Date
    var recovery: DailyRecoveryData
    var effort: DailyEffortData
    var sleep: DailySleepData
    var activity: DailyActivityData
    var vitals: DailyHealthMetricsData
    var nutrition: DailyNutritionData
    var connectedSources: [String]
    var syncedAt: Date

    init(date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        self.dateKey = formatter.string(from: date)
        self.date = Calendar.current.startOfDay(for: date)
        self.recovery = DailyRecoveryData()
        self.effort = DailyEffortData()
        self.sleep = DailySleepData()
        self.activity = DailyActivityData()
        self.vitals = DailyHealthMetricsData()
        self.nutrition = DailyNutritionData()
        self.connectedSources = []
        self.syncedAt = Date()
    }
}

struct UserHealthBaselines: Codable {
    var hrv: Double = 0
    var hrvStd: Double = 0
    var restingHeartRate: Double = 0
    var restingHeartRateStd: Double = 0
    var sleepNeedHours: Double = 8
    var sleepNeedStd: Double = 0
    var effortCapacity: Double = 15
    var avgDailySteps: Double = 0
    var avgActiveCalories: Double = 0
    var calculatedAt: Date = Date()
    var daysOfData: Int = 0

    var finalBaselines: FinalBaselines {
        FinalBaselines(
            hrv: hrv,
            hrvStd: hrvStd,
            rhr: restingHeartRate,
            rhrStd: restingHeartRateStd,
            sleepNeed: sleepNeedHours,
            sleepNeedStd: sleepNeedStd,
            effortCapacity: effortCapacity,
            recoverySpeed: 2,
            stressTolerance: 50
        )
    }

    static func from(_ baselines: FinalBaselines, days: Int) -> UserHealthBaselines {
        UserHealthBaselines(
            hrv: baselines.hrv,
            hrvStd: baselines.hrvStd,
            restingHeartRate: baselines.rhr,
            restingHeartRateStd: baselines.rhrStd,
            sleepNeedHours: baselines.sleepNeed,
            sleepNeedStd: baselines.sleepNeedStd,
            effortCapacity: baselines.effortCapacity,
            calculatedAt: Date(),
            daysOfData: days
        )
    }
}
