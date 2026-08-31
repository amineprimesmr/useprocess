import Foundation

/// Cible précise du contour tutoriel — carte / carousel, jamais le titre de section.
enum PlanHomeTutorialFocus: String, Equatable, Hashable {
    case faceScan
    case hydration
    case meals
    case faceRoutine

    var scrollAnchorID: String {
        "plan.home.tutorial.\(rawValue)"
    }

    var cornerRadius: CGFloat {
        PlanHomeTutorialMetrics.sectionCornerRadius
    }
}
