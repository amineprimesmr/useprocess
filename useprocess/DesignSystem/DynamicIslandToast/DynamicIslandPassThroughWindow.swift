import SwiftUI

@Observable
final class DynamicIslandPassThroughWindow: UIWindow {
    var toast: DynamicIslandToastMessage?
    var isPresented = false
    var onToastTap: (() -> Void)?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isPresented else { return nil }
        return super.hitTest(point, with: event)
    }
}
