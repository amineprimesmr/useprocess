import SwiftUI
import UIKit

// MARK: - Coordinator (install unique, zéro timer)

/// Gère le conflit scroll vertical vs swipe horizontal TabView — sans polling.
/// Ne jamais assigner `panGestureRecognizer.delegate` sur un UIScrollView (crash iOS).
final class ProcessMainPagingCoordinator: NSObject {
    static let shared = ProcessMainPagingCoordinator()

    private(set) weak var pagingScrollView: UIScrollView?
    private var hookedScrollViews = NSHashTable<UIScrollView>.weakObjects()
    private var verticalPanHookedScrollViews = NSHashTable<UIScrollView>.weakObjects()
    private weak var panHookedPager: UIScrollView?
    private(set) var isVerticalDragActive = false
    private var isInstalled = false
    private var centerTouchPending = false
    var swipeFullyDisabled = false

    private let edgeActivationWidth: CGFloat = 36

    func setSwipeFullyDisabled(_ disabled: Bool) {
        guard swipeFullyDisabled != disabled else { return }
        swipeFullyDisabled = disabled
        applyPagingEnabled()
    }

    func setVerticalDragActive(_ active: Bool) {
        guard isVerticalDragActive != active else { return }
        isVerticalDragActive = active
        applyPagingEnabled()
    }

    /// Installation unique depuis la fenêtre — pas de timer, pas de walk répété.
    func installIfNeeded(from view: UIView) {
        guard !isInstalled, view.window != nil else { return }
        guard let pager = findHorizontalPager(in: view.window!) else { return }

        isInstalled = true
        pagingScrollView = pager
        pager.isDirectionalLockEnabled = true
        pager.alwaysBounceVertical = false
        hookPagerPanIfNeeded(pager)
        applyPagingEnabled()
    }

    func hookVerticalScrollView(from probe: UIView) {
        guard let scroll = enclosingVerticalScrollView(startingFrom: probe) else { return }
        guard !hookedScrollViews.contains(scroll) else { return }
        hookedScrollViews.add(scroll)
        scroll.isDirectionalLockEnabled = true
        hookVerticalPanIfNeeded(scroll)
    }

    func teardown() {
        isInstalled = false
        pagingScrollView = nil
        isVerticalDragActive = false
        centerTouchPending = false
    }

    private func hookPagerPanIfNeeded(_ scroll: UIScrollView) {
        guard panHookedPager !== scroll else { return }
        panHookedPager = scroll
        scroll.panGestureRecognizer.addTarget(self, action: #selector(handlePagerPan(_:)))
    }

    private func hookVerticalPanIfNeeded(_ scroll: UIScrollView) {
        guard !verticalPanHookedScrollViews.contains(scroll) else { return }
        verticalPanHookedScrollViews.add(scroll)
        scroll.panGestureRecognizer.addTarget(self, action: #selector(handleVerticalScrollPan(_:)))
    }

    private func applyPagingEnabled() {
        guard let pager = pagingScrollView else { return }
        let lock = swipeFullyDisabled || isVerticalDragActive || centerTouchPending
        pager.isScrollEnabled = !lock
    }

    @objc private func handleVerticalScrollPan(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .began, .changed:
            let translation = sender.translation(in: sender.view)
            guard abs(translation.y) > abs(translation.x), abs(translation.y) > 3 else { return }
            setVerticalDragActive(true)
        case .ended, .cancelled, .failed:
            setVerticalDragActive(false)
        default:
            break
        }
    }

    @objc private func handlePagerPan(_ sender: UIPanGestureRecognizer) {
        guard let pager = pagingScrollView else { return }

        if swipeFullyDisabled || isVerticalDragActive {
            if sender.state == .began || sender.state == .changed {
                pager.isScrollEnabled = false
            } else {
                applyPagingEnabled()
            }
            return
        }

        switch sender.state {
        case .began:
            let location = sender.location(in: pager.window ?? pager)
            let screenW = pager.window?.bounds.width ?? pager.bounds.width
            let nearEdge = location.x <= edgeActivationWidth || location.x >= screenW - edgeActivationWidth
            centerTouchPending = !nearEdge
            if centerTouchPending {
                pager.isScrollEnabled = false
            } else {
                applyPagingEnabled()
            }

        case .changed:
            guard centerTouchPending else { return }
            let translation = sender.translation(in: pager)
            let dx = abs(translation.x)
            let dy = abs(translation.y)

            if dy > dx * 0.85, dy > 4 {
                setVerticalDragActive(true)
                centerTouchPending = false
                return
            }

            guard dx > 6 || dy > 6 else { return }

            if dx > dy {
                snapPagerToNearestPage(pager)
                pager.isScrollEnabled = false
            } else {
                centerTouchPending = false
                setVerticalDragActive(true)
            }

        case .ended, .cancelled, .failed:
            centerTouchPending = false
            applyPagingEnabled()

        default:
            break
        }
    }

    private func snapPagerToNearestPage(_ pager: UIScrollView) {
        let pageWidth = max(pager.bounds.width, 1)
        let page = round(pager.contentOffset.x / pageWidth)
        pager.setContentOffset(CGPoint(x: page * pageWidth, y: 0), animated: false)
    }

    private func findHorizontalPager(in root: UIView) -> UIScrollView? {
        var candidates: [UIScrollView] = []
        func walk(_ view: UIView) {
            if let scroll = view as? UIScrollView { candidates.append(scroll) }
            view.subviews.forEach(walk)
        }
        walk(root)

        return candidates
            .filter { scroll in
                let width = scroll.bounds.width
                guard width > 50 else { return false }
                let contentW = scroll.contentSize.width
                if scroll.isPagingEnabled, contentW > width * 1.4 { return true }
                return contentW > width * 2.2
            }
            .max(by: { $0.contentSize.width < $1.contentSize.width })
    }

    private func enclosingVerticalScrollView(startingFrom view: UIView) -> UIScrollView? {
        var candidate: UIView? = view
        while let current = candidate {
            if let scroll = current as? UIScrollView,
               scroll !== pagingScrollView,
               !scroll.isPagingEnabled,
               scroll.contentSize.height > scroll.bounds.height + 1,
               scroll.bounds.height > 80 {
                return scroll
            }
            candidate = current.superview
        }
        return nil
    }
}

// MARK: - Host UIKit

struct ProcessMainTabPagingHost: UIViewControllerRepresentable {
    let swipeFullyDisabled: Bool

    func makeUIViewController(context: Context) -> ProcessMainTabPagingHostController {
        ProcessMainTabPagingHostController()
    }

    func updateUIViewController(_ controller: ProcessMainTabPagingHostController, context: Context) {
        controller.setSwipeFullyDisabled(swipeFullyDisabled)
    }
}

final class ProcessMainTabPagingHostController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ProcessMainPagingCoordinator.shared.installIfNeeded(from: view)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ProcessMainPagingCoordinator.shared.teardown()
    }

    func setSwipeFullyDisabled(_ disabled: Bool) {
        ProcessMainPagingCoordinator.shared.setSwipeFullyDisabled(disabled)
    }
}

// MARK: - Hook scroll vertical (une seule fois à la création)

private struct ProcessVerticalScrollHook: UIViewRepresentable {
    func makeUIView(context: Context) -> HookView {
        let view = HookView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: HookView, context: Context) {}

    final class HookView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            ProcessMainPagingCoordinator.shared.installIfNeeded(from: self)
            ProcessMainPagingCoordinator.shared.hookVerticalScrollView(from: self)
        }
    }
}

extension View {
    func processMainTabPaging(swipeDisabled: Bool = false) -> some View {
        background(ProcessMainTabPagingHost(swipeFullyDisabled: swipeDisabled))
    }

    func processMainTabSwipeDisabled(_ disabled: Bool) -> some View {
        processMainTabPaging(swipeDisabled: disabled)
    }

    func processMainVerticalScrollHook() -> some View {
        background(ProcessVerticalScrollHook())
    }
}
