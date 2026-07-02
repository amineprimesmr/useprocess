import SwiftUI

final class DynamicIslandToastHostingController: UIHostingController<DynamicIslandToastContentView> {
    var isStatusBarHidden = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    override var prefersStatusBarHidden: Bool {
        isStatusBarHidden
    }
}
