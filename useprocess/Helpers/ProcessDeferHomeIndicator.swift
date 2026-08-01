import SwiftUI
import UIKit
import ObjectiveC

/// Force un **double swipe** Home + callback au 1er swipe.
/// Réservé au paywall — se désactive dès que l’écran disparaît.
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

    static func installHostingControllerForwardingIfNeeded() {
        guard !didInstall else { return }
        didInstall = true

        let original = class_getInstanceMethod(
            UIViewController.self,
            #selector(getter: UIViewController.childForScreenEdgesDeferringSystemGestures)
        )
        let replacement = class_getInstanceMethod(
            UIViewController.self,
            #selector(UIViewController.process_childForScreenEdgesDeferringSystemGestures)
        )
        guard let original, let replacement else { return }
        method_exchangeImplementations(original, replacement)
    }
}

private extension UIViewController {
    @objc func process_childForScreenEdgesDeferringSystemGestures() -> UIViewController? {
        // Uniquement un enfant direct encore actif (évite crash / récursion).
        if let deferral = children
            .compactMap({ $0 as? ProcessDeferHomeHostingController })
            .first(where: \.isDeferralActive) {
            return deferral
        }
        return process_childForScreenEdgesDeferringSystemGestures()
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
        isDeferralEnabled = true
        edgePan?.isEnabled = true
        notifyScreenEdgesChanged()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        deactivateDeferral()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        deactivateDeferral()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let superview = view.superview {
            view.frame = superview.bounds
        }
    }

    func deactivateDeferral() {
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
        let edgeHeight: CGFloat = 64
        guard bounds.height > 0, point.y >= bounds.height - edgeHeight else { return nil }
        return super.hitTest(point, with: event)
    }
}

extension View {
    /// 1er swipe Home = callback ; 2e swipe = sortie système.
    /// Réservé au paywall — se désactive automatiquement à la disparition de l’écran.
    func processRequireDoubleHomeSwipe(onFirstSwipe: (() -> Void)? = nil) -> some View {
        background(
            ProcessDeferHomeIndicatorController(onDeferredBottomSwipe: onFirstSwipe)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(true)
        )
        .overlay(alignment: .bottom) {
            Color.clear
                .frame(height: 28)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onEnded { value in
                            guard value.translation.height < -18 else { return }
                            onFirstSwipe?()
                        }
                )
        }
    }
}
