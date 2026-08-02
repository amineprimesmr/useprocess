import Combine
import Foundation

/// Double-swipe Home pendant tout le pré-accès (téléchargement → onboarding → paywall),
/// jusqu’à l’entrée dans l’app. Le pop « Attends ! » ne s’affiche que sur le paywall.
@MainActor
final class ProcessPreAccessHomeSwipeCoordinator: ObservableObject {
    static let shared = ProcessPreAccessHomeSwipeCoordinator()

    enum RetentionSurface: Equatable {
        case none
        case paywall
        case spinWinback
    }

    /// Surface qui peut réagir au 1er swipe (pop rétention).
    @Published var retentionSurface: RetentionSurface = .none

    /// Incrémenté à chaque 1er swipe Home — le paywall observe ce token.
    @Published private(set) var swipeToken: Int = 0

    private init() {}

    func handleFirstSwipe() {
        swipeToken &+= 1
    }

    var shouldShowPaywallStayPopup: Bool {
        retentionSurface == .paywall
    }
}
