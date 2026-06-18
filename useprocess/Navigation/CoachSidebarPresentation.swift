import SwiftUI

/// État global du panneau latéral coach — évite de faire remonter des preferences à chaque frame.
@MainActor
@Observable
final class CoachSidebarPresentation {
    static let shared = CoachSidebarPresentation()

    private(set) var progress: CGFloat = 0
    private(set) var isExpanded = false

    private init() {}

    func setProgress(_ value: CGFloat) {
        let clamped = min(max(value, 0), 1)
        guard abs(clamped - progress) > 0.0005 else { return }
        progress = clamped
    }

    func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
    }

    func sync(offset: CGFloat, width: CGFloat, expanded: Bool) {
        if width > 0 {
            setProgress(offset / width)
        }
        setExpanded(expanded)
    }
}
