import Foundation

/// Cibles quotidiennes debloat — nombres fixes (pas de fourchettes).
enum ProcessDailyTargets {

    // MARK: - Hydratation
    nonisolated static let hydrationLitersPerDay = 3
    static var hydrationLabel: String { "\(hydrationLitersPerDay) L" }
    nonisolated static var hydrationTargetMilliliters: Int { hydrationLitersPerDay * 1000 }

    // MARK: - Matin
    static let warmWaterOnWakeML = 500
    static let lymphJumpSeconds = 60
    static let lymphKneeRaiseSeconds = 60
    static let lymphArmRaiseSeconds = 60
    static let morningLightMinutes = 100
    static let faceScanSeconds = 30
    static let coldFaceRinseSeconds = 30

    // MARK: - Journée
    static let dailySteps = 8000
    static let chewsPerBite = 25
    static let lymphFaceMassageMinutes = 1

    // MARK: - Sommeil
    static let sleepHours = 8
    static let bedroomTempCelsius = 18
    static let screenCurfewMinutes = 60
    static let caffeineCutoffHour = 14
    static let sleepScheduleMarginMinutes = 30

    // MARK: - Hebdo
    static let outdoorWalkSessionsPerWeek = 2
    static let restDaysPerWeek = 2
}
