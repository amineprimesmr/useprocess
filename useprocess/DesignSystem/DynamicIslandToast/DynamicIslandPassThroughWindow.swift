import SwiftUI

@Observable
final class DynamicIslandPassThroughWindow: UIWindow {
    var toast: DynamicIslandToastMessage?
    var isPresented = false

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event),
              let rootView = rootViewController?.view else {
            return nil
        }

        if #available(iOS 26, *) {
            if rootView.layer.hitTest(point)?.name == nil {
                return rootView
            }
            return nil
        }

        if #unavailable(iOS 18) {
            return hitView == rootView ? nil : hitView
        }

        for subview in rootView.subviews.reversed() {
            let pointInSubView = subview.convert(point, from: rootView)
            if subview.hitTest(pointInSubView, with: event) != nil {
                return hitView
            }
        }

        return nil
    }
}
