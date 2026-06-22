import SwiftUI
import UIKit

/// Active / désactive le swipe horizontal du TabView principal (ex. gating Welcome Plan).
final class ProcessMainPagingCoordinator: NSObject {
    static let shared = ProcessMainPagingCoordinator()

    private(set) weak var pagingScrollView: UIScrollView?
    private var isInstalled = false
    var swipeFullyDisabled = false

    private override init() {
        super.init()
    }

    func setSwipeFullyDisabled(_ disabled: Bool) {
        guard swipeFullyDisabled != disabled else { return }
        swipeFullyDisabled = disabled
        applyPagingEnabled()
    }

    func installIfNeeded(from view: UIView) {
        guard !isInstalled, view.window != nil else { return }
        guard let pager = findHorizontalPager(in: view.window!) else { return }

        isInstalled = true
        pagingScrollView = pager
        pager.isDirectionalLockEnabled = true
        pager.alwaysBounceVertical = false
        applyPagingEnabled()
    }

    func teardown() {
        isInstalled = false
        pagingScrollView = nil
    }

    private func applyPagingEnabled() {
        pagingScrollView?.isScrollEnabled = !swipeFullyDisabled
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
}

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

private struct ProcessMainTabPagingInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            ProcessMainPagingCoordinator.shared.installIfNeeded(from: self)
        }
    }
}

extension View {
    func processMainTabPaging(swipeDisabled: Bool = false) -> some View {
        background {
            ProcessMainTabPagingHost(swipeFullyDisabled: swipeDisabled)
            ProcessMainTabPagingInstaller()
        }
    }

    func processMainTabSwipeDisabled(_ disabled: Bool) -> some View {
        processMainTabPaging(swipeDisabled: disabled)
    }

    /// Conservé pour compatibilité — n’installe plus de hooks qui bloquaient le swipe.
    func processMainVerticalScrollHook() -> some View {
        self
    }
}
