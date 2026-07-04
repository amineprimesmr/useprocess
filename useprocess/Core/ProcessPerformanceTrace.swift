import Foundation
import os.signpost

/// Signposts visibles dans Instruments > Points of Interest.
/// Mesure le délai entre le geste utilisateur et la première apparition de la
/// destination, sans collecter de contenu utilisateur.
@MainActor
enum ProcessPerformanceTrace {
    private static let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "com.useprocess",
        category: .pointsOfInterest
    )

    private static var coachID: OSSignpostID?
    private static var mealID: OSSignpostID?
    private static var profileID: OSSignpostID?

    static func beginCoachOpen() {
        guard coachID == nil else { return }
        let id = OSSignpostID(log: log)
        coachID = id
        os_signpost(.begin, log: log, name: "Open Coach", signpostID: id)
    }

    static func endCoachOpen() {
        guard let id = coachID else { return }
        os_signpost(.end, log: log, name: "Open Coach", signpostID: id)
        coachID = nil
    }

    static func beginMealOpen() {
        guard mealID == nil else { return }
        let id = OSSignpostID(log: log)
        mealID = id
        os_signpost(.begin, log: log, name: "Open Meal Detail", signpostID: id)
    }

    static func endMealOpen() {
        guard let id = mealID else { return }
        os_signpost(.end, log: log, name: "Open Meal Detail", signpostID: id)
        mealID = nil
    }

    static func beginProfileOpen() {
        guard profileID == nil else { return }
        let id = OSSignpostID(log: log)
        profileID = id
        os_signpost(.begin, log: log, name: "Open Profile", signpostID: id)
    }

    static func endProfileOpen() {
        guard let id = profileID else { return }
        os_signpost(.end, log: log, name: "Open Profile", signpostID: id)
        profileID = nil
    }
}
