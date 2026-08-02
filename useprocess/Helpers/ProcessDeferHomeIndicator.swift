import SwiftUI
import UIKit
import ObjectiveC

/// Force un **double swipe** Home + callback au 1er swipe.
/// Monté au niveau AppShell pendant tout le pré-accès (stable), pas seulement sur le paywall.
struct ProcessDeferHomeIndicatorController: UIViewControllerRepresentable {
    var onDeferredBottomSwipe: (() -> Void)?

    func makeUIViewController(context: Context) -> ProcessDeferHomeHostingController {
        ProcessHomeGestureDeferral.installHostingControllerForwardingIfNeeded()
        let controller = ProcessDeferHomeHostingController()
        controller.onDeferredBottomSwipe = onDeferredBottomSwipe
        return controller
    }

    func updateUIViewController(_ uiViewController: ProcessDeferHomeHostingController, context: Context) {
        uiViewController.onDeferredBottomSwipe = onDeferredBottomSwipe
        uiViewController.reactivateIfVisible()
    }

    static func dismantleUIViewController(
        _ uiViewController: ProcessDeferHomeHostingController,
        coordinator: Void
    ) {
        uiViewController.deactivateDeferral()
    }
}

enum ProcessHomeGestureDeferral {
    private static var didInstall = false

    /// Controllers encore actifs (weak) — plus fiable que la seule hiérarchie SwiftUI.
    fileprivate static var activeControllers = NSHashTable<ProcessDeferHomeHostingController>.weakObjects()

    static func installHostingControllerForwardingIfNeeded() {
        guard !didInstall else { return }
        didInstall = true

        if let original = class_getInstanceMethod(
            UIViewController.self,
            #selector(getter: UIViewController.childForScreenEdgesDeferringSystemGestures)
        ),
           let replacement = class_getInstanceMethod(
            UIViewController.self,
            #selector(UIViewController.process_childForScreenEdgesDeferringSystemGestures)
           ) {
            method_exchangeImplementations(original, replacement)
        }

        // Filet : le root SwiftUI déclare aussi le deferral bottom (sans dépendre du nesting).
        if let originalEdges = class_getInstanceMethod(
            UIViewController.self,
            #selector(getter: UIViewController.preferredScreenEdgesDeferringSystemGestures)
        ),
           let replacementEdges = class_getInstanceMethod(
            UIViewController.self,
            #selector(UIViewController.process_preferredScreenEdgesDeferringSystemGestures)
           ) {
            method_exchangeImplementations(originalEdges, replacementEdges)
        }
    }

    fileprivate static func shouldForceBottomDeferral(for host: UIViewController) -> Bool {
        guard let active = activeControllers.allObjects.first(where: \.isDeferralActive) else { return false }
        guard let window = active.viewIfLoaded?.window else { return host === active }
        return host === active || window.rootViewController === host
    }

    fileprivate static func register(_ controller: ProcessDeferHomeHostingController) {
        activeControllers.add(controller)
    }

    fileprivate static func unregister(_ controller: ProcessDeferHomeHostingController) {
        activeControllers.remove(controller)
    }

    fileprivate static func preferredActiveController(
        relativeTo host: UIViewController
    ) -> ProcessDeferHomeHostingController? {
        let registered = activeControllers.allObjects.filter(\.isDeferralActive)
        // Préfère un descendant du VC interrogé, sinon n’importe quel actif dans la même window.
        if let nested = registered.first(where: { host.process_containsDescendant($0) }) {
            return nested
        }
        let hostWindow = host.viewIfLoaded?.window
        return registered.first(where: { $0.viewIfLoaded?.window === hostWindow || hostWindow == nil })
    }
}

private extension UIViewController {
    @objc func process_preferredScreenEdgesDeferringSystemGestures() -> UIRectEdge {
        if ProcessHomeGestureDeferral.shouldForceBottomDeferral(for: self) {
            return .bottom
        }
        return process_preferredScreenEdgesDeferringSystemGestures()
    }

    @objc func process_childForScreenEdgesDeferringSystemGestures() -> UIViewController? {
        if let deferral = ProcessHomeGestureDeferral.preferredActiveController(relativeTo: self) {
            // Si ce n’est pas un descendant, on s’appuie quand même sur la recherche locale.
            if process_containsDescendant(deferral) {
                return deferral
            }
        }
        if let nested = process_findActiveDeferralController() {
            return nested
        }
        return process_childForScreenEdgesDeferringSystemGestures()
    }

    func process_containsDescendant(_ other: UIViewController) -> Bool {
        var walker: UIViewController? = other
        while let current = walker {
            if current === self { return true }
            walker = current.parent
        }
        return false
    }

    /// Remonte enfants + presented (SwiftUI / fullScreenCover).
    func process_findActiveDeferralController() -> ProcessDeferHomeHostingController? {
        var queue: [UIViewController] = children
        if let presented = presentedViewController {
            queue.append(presented)
        }
        var index = 0
        while index < queue.count {
            let child = queue[index]
            index += 1
            if let deferral = child as? ProcessDeferHomeHostingController, deferral.isDeferralActive {
                return deferral
            }
            queue.append(contentsOf: child.children)
            if let presented = child.presentedViewController {
                queue.append(presented)
            }
        }
        return nil
    }
}

final class ProcessDeferHomeHostingController: UIViewController, UIGestureRecognizerDelegate {
    var onDeferredBottomSwipe: (() -> Void)?

    private var edgePan: UIScreenEdgePanGestureRecognizer?
    private var lastCallbackAt: Date?
    private var isDeferralEnabled = true

    var isDeferralActive: Bool {
        isDeferralEnabled
            && viewIfLoaded?.window != nil
            && !isBeingDismissed
            && !isMovingFromParent
    }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        isDeferralActive ? .bottom : []
    }

    override var prefersHomeIndicatorAutoHidden: Bool { false }

    override func loadView() {
        let passthrough = ProcessDeferHomePassthroughView()
        passthrough.backgroundColor = .clear
        view = passthrough
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let pan = UIScreenEdgePanGestureRecognizer(
            target: self,
            action: #selector(handleBottomEdgePan(_:))
        )
        pan.edges = .bottom
        pan.delegate = self
        pan.cancelsTouchesInView = false
        view.addGestureRecognizer(pan)
        edgePan = pan
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reactivateIfVisible()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Ne pas désactiver ici — les transitions SwiftUI cassent sinon le double-swipe.
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if view.window == nil {
            deactivateDeferral()
        }
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent != nil {
            reactivateIfVisible()
        } else if viewIfLoaded?.window == nil {
            deactivateDeferral()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let superview = view.superview {
            view.frame = superview.bounds
        }
        reactivateIfVisible()
    }

    func reactivateIfVisible() {
        guard viewIfLoaded?.window != nil,
              !isBeingDismissed,
              !isMovingFromParent else { return }
        isDeferralEnabled = true
        edgePan?.isEnabled = true
        ProcessHomeGestureDeferral.register(self)
        notifyScreenEdgesChanged()
    }

    func deactivateDeferral() {
        ProcessHomeGestureDeferral.unregister(self)
        guard isDeferralEnabled else {
            notifyScreenEdgesChanged()
            return
        }
        isDeferralEnabled = false
        edgePan?.isEnabled = false
        notifyScreenEdgesChanged()
    }

    private func notifyScreenEdgesChanged() {
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        var walker: UIViewController? = parent
        while let current = walker {
            current.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
            walker = current.parent
        }
        // Remonte aussi jusqu’au root de la window (UIHostingController SwiftUI).
        if let root = view.window?.rootViewController {
            root.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
            var presented: UIViewController? = root
            while let current = presented {
                current.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
                presented = current.presentedViewController
            }
        }
    }

    @objc private func handleBottomEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard isDeferralActive else { return }
        switch gesture.state {
        case .began:
            fireDeferredSwipeIfNeeded()
        case .changed, .ended:
            let translation = gesture.translation(in: view)
            if translation.y < -10 {
                fireDeferredSwipeIfNeeded()
            }
        default:
            break
        }
    }

    private func fireDeferredSwipeIfNeeded() {
        guard isDeferralActive else { return }
        let now = Date()
        if let lastCallbackAt, now.timeIntervalSince(lastCallbackAt) < 1.2 { return }
        lastCallbackAt = now
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isDeferralActive else { return }
            self.onDeferredBottomSwipe?()
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }
}

private final class ProcessDeferHomePassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let edgeHeight: CGFloat = 80
        guard bounds.height > 0, point.y >= bounds.height - edgeHeight else { return nil }
        return super.hitTest(point, with: event)
    }
}

extension View {
    /// 1er swipe Home = callback ; 2e swipe = sortie système.
    func processRequireDoubleHomeSwipe(onFirstSwipe: (() -> Void)? = nil) -> some View {
        background(
            ProcessDeferHomeIndicatorController(onDeferredBottomSwipe: onFirstSwipe)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(true)
        )
        .overlay(alignment: .bottom) {
            Color.clear
                .frame(height: 36)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onEnded { value in
                            guard value.translation.height < -16 else { return }
                            onFirstSwipe?()
                        }
                )
        }
    }

    /// Double-swipe Home pendant tout le pré-accès (onboarding → paywall).
    @ViewBuilder
    func processPreAccessDoubleHomeSwipe(isActive: Bool) -> some View {
        if isActive {
            processRequireDoubleHomeSwipe {
                ProcessPreAccessHomeSwipeCoordinator.shared.handleFirstSwipe()
            }
        } else {
            self
        }
    }
}
