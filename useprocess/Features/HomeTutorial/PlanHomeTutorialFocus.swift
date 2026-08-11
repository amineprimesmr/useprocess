import Foundation

/// Cible précise du contour tutoriel — carte / carousel, jamais le titre de section.
enum PlanHomeTutorialFocus: String, Equatable {
    case faceScan
    case hydration
    case meals
    case faceRoutine
    case training

    var scrollAnchorID: String {
        "plan.home.tutorial.\(rawValue)"
    }

    var cornerRadius: CGFloat {
        PlanHomeTutorialMetrics.sectionCornerRadius
    }
}
