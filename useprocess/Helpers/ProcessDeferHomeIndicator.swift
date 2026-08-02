import SwiftUI
import UIKit

/// Double-swipe Home pendant le pré-accès — **sans method swizzling UIKit**
/// (swizzle global = risque de crash au cold launch sur devices App Review).
///
/// Stratégie sûre :
/// 1. VC dédié qui déclare `preferredScreenEdgesDeferringSystemGestures = .bottom`
/// 2. Edge-pan + DragGesture SwiftUI pour le callback « 1er swipe »
struct ProcessDeferHomeIndicatorController: UIViewControllerRepresentable {
    var onDeferredBottomSwipe: (() -> Void)?

    func makeUIViewController(context: Context) -> ProcessDeferHomeHostingController {
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
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        parent?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }

    func deactivateDeferral() {
        guard isDeferralEnabled else {
            setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
            return
        }
        isDeferralEnabled = false
        edgePan?.isEnabled = false
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        parent?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
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

    /// Double-swipe Home pendant le pré-accès (onboarding → paywall).
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
