import Foundation
import HealthKit

enum HealthKitTypes {

    // MARK: - Lecture (vague 1 + 2)

    static var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        let quantityIds: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .distanceWalkingRunning,
            .distanceCycling,
            .activeEnergyBurned,
            .basalEnergyBurned,
            .appleExerciseTime,
            .flightsClimbed,
            .heartRate,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .oxygenSaturation,
            .respiratoryRate,
            .vo2Max,
            .bodyMass,
            .height,
            .bodyFatPercentage,
            .leanBodyMass,
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
            .dietaryWater,
            .appleStandTime,
            .walkingSpeed,
            .walkingStepLength,
            .walkingAsymmetryPercentage,
            .walkingDoubleSupportPercentage,
            .appleWalkingSteadiness
        ]

        for id in quantityIds {
            if let type = HKQuantityType.quantityType(forIdentifier: id) {
                types.insert(type)
            }
        }

        let categoryIds: [HKCategoryTypeIdentifier] = [
            .sleepAnalysis,
            .appleStandHour,
            .mindfulSession,
            .highHeartRateEvent,
            .lowHeartRateEvent
        ]

        for id in categoryIds {
            if let type = HKCategoryType.categoryType(forIdentifier: id) {
                types.insert(type)
            }
        }

        types.insert(HKObjectType.workoutType())

        if let wristTemp = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
            types.insert(wristTemp)
        }

        return types
    }

    // MARK: - Écriture (minimale)

    static var writeTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        if let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }

    static var observerTypes: [HKSampleType] {
        [
            HKQuantityType.quantityType(forIdentifier: .stepCount),
            HKQuantityType.quantityType(forIdentifier: .heartRate),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.workoutType()
        ].compactMap { $0 }
    }
}
