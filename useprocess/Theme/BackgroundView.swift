import SwiftUI
import UIKit

/// Tokens du fond app — uni en clair et en sombre.
enum ProcessBackgroundPalette {
    /// Gris très clair (pas blanc pur).
    static let lightBase = Color(red: 0.925, green: 0.927, blue: 0.933)
    static let darkBase = Color(red: 0.07, green: 0.08, blue: 0.11)

    static func base(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkBase : lightBase
    }

    static func uiColor(for colorScheme: ColorScheme) -> UIColor {
        switch colorScheme {
        case .dark:
            UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1)
        default:
            UIColor(red: 0.925, green: 0.927, blue: 0.933, alpha: 1)
        }
    }
}

/// Fond principal de l’app — plat (plus de dégradé rosé / violet en clair).
struct ProcessScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                ProcessBackgroundPalette.darkBase
            } else {
                ProcessBackgroundPalette.lightBase
            }
        }
        .ignoresSafeArea()
    }
}

/// Alias historique — même fond que `ProcessScreenBackground`.
struct BackgroundView: View {
    var body: some View {
        ProcessScreenBackground()
    }
}

/// Voile léger au-dessus de la page parente (accueil visible en transparence).
struct ProcessTranslucentOverlayBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            if colorScheme == .dark {
                Color.black.opacity(0.16)
            } else {
                Color.white.opacity(0.24)
            }
        }
        .ignoresSafeArea()
    }
}

/// Force les UIScrollView / UINavigationController parents à rester transparents (TabView + NavigationStack).
private struct ProcessUIKitOpaqueSurface: UIViewRepresentable {
    var color: UIColor

    func makeUIView(context: Context) -> ProcessUIKitOpaqueSurfaceView {
        let view = ProcessUIKitOpaqueSurfaceView()
        view.fillColor = color
        return view
    }

    func updateUIView(_ uiView: ProcessUIKitOpaqueSurfaceView, context: Context) {
        uiView.fillColor = color
        uiView.restoreHostingSurfaces()
    }
}

private final class ProcessUIKitOpaqueSurfaceView: UIView {
    var fillColor: UIColor = .systemBackground

    override func didMoveToWindow() {
        super.didMoveToWindow()
        restoreHostingSurfaces()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        restoreHostingSurfaces()
    }

    func restoreHostingSurfaces() {
        guard window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.applyOpaqueBackground()
        }
    }

    private func applyOpaqueBackground() {
        var cursor: UIView? = self
        while let view = cursor {
            let size = view.bounds.size
            if size.width >= UIScreen.main.bounds.width * 0.9
                && size.height >= UIScreen.main.bounds.height * 0.45 {
                view.backgroundColor = fillColor
                view.isOpaque = true
            }
            cursor = view.superview
        }

        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController {
                controller.view.backgroundColor = fillColor
                controller.view.isOpaque = true
                break
            }
            responder = current.next
        }
    }
}

private struct ProcessUIKitTransparentSurface: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        ProcessUIKitTransparentSurfaceView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private final class ProcessUIKitTransparentSurfaceView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        scheduleClear()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scheduleClear()
    }

    private func scheduleClear() {
        guard window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.clearHostingSurfaces()
        }
    }

    private func clearHostingSurfaces() {
        var visited = Set<ObjectIdentifier>()
        clearFrom(view: self, visited: &visited)

        if let controller = nearestViewController() {
            clearFrom(view: controller.view, visited: &visited)
            if let navigationController = controller.navigationController {
                clearFrom(view: navigationController.view, visited: &visited)
            }
            if let tabController = controller.tabBarController {
                clearFrom(view: tabController.view, visited: &visited)
            }
        }
    }

    private func clearFrom(view: UIView, visited: inout Set<ObjectIdentifier>) {
        let id = ObjectIdentifier(view)
        guard !visited.contains(id) else { return }
        visited.insert(id)

        if let scrollView = view as? UIScrollView {
            scrollView.backgroundColor = .clear
            scrollView.isOpaque = false
        } else if view.backgroundColor != nil && view !== self {
            // Couche pleine écran typique du conteneur SwiftUI (blanc système).
            let size = view.bounds.size
            if size.width >= UIScreen.main.bounds.width * 0.9
                && size.height >= UIScreen.main.bounds.height * 0.35
                && view.subviews.count > 0 {
                view.backgroundColor = .clear
                view.isOpaque = false
            }
        }

        view.subviews.forEach { clearFrom(view: $0, visited: &visited) }
    }

    private func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController {
                return controller
            }
            responder = current.next
        }
        return nil
    }
}

// MARK: - Scroll compatible fermeture zoom (détail repas, etc.)

private enum ProcessScrollContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private enum ProcessScrollViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ProcessUIScrollViewBounceDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = uiView.processEnclosingScrollView else { return }
            scrollView.alwaysBounceVertical = false
        }
    }
}

private extension UIView {
    var processEnclosingScrollView: UIScrollView? {
        var view: UIView? = self
        while let current = view {
            if let scroll = current as? UIScrollView { return scroll }
            view = current.superview
        }
        return nil
    }
}

private struct ProcessZoomDismissFriendlyScrollModifier: ViewModifier {
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

    private var needsScroll: Bool {
        guard contentHeight > 0, viewportHeight > 0 else { return true }
        return contentHeight > viewportHeight + 2
    }

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ProcessScrollViewportHeightKey.self, value: proxy.size.height)
                }
            }
            .onPreferenceChange(ProcessScrollContentHeightKey.self) { contentHeight = $0 }
            .onPreferenceChange(ProcessScrollViewportHeightKey.self) { viewportHeight = $0 }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .scrollDisabled(!needsScroll)
            .background(ProcessUIScrollViewBounceDisabler())
    }
}

extension View {
    /// Mesure la hauteur du contenu d’un `ScrollView` (pair avec `processZoomDismissFriendlyScroll()`).
    func processReportsScrollContentHeight() -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ProcessScrollContentHeightKey.self, value: proxy.size.height)
            }
        }
    }

    /// Pas de rebond vers le bas au top — tirer vers le bas ferme la cover zoom ; scroll seulement si le contenu dépasse.
    func processZoomDismissFriendlyScroll() -> some View {
        modifier(ProcessZoomDismissFriendlyScrollModifier())
    }

    /// Contenu au-dessus du dégradé — ZStack (fiable vs `.background` sur NavigationStack).
    func processScreenBackground() -> some View {
        ZStack {
            ProcessScreenBackground()
            self
        }
    }

    /// Scroll principal transparent pour laisser voir le dégradé clair.
    func processTransparentScrollSurface() -> some View {
        scrollContentBackground(.hidden)
    }

    /// Nettoie les fonds UIKit opaques injectés par TabView / NavigationStack.
    func processClearUIKitHostingBackground() -> some View {
        background {
            ProcessUIKitTransparentSurface()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
    }

    /// Remet un fond UIKit opaque — à appeler après un aperçu qui a clear le hosting parent.
    func processRestoreOpaqueUIKitHostingBackground(_ color: UIColor = .systemBackground) -> some View {
        background {
            ProcessUIKitOpaqueSurface(color: color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
    }

    /// Fond page plein écran — même dégradé que l’accueil + transparence navigation/scroll.
    func processAppPageBackground() -> some View {
        ZStack {
            ProcessScreenBackground()
            self
        }
        .processClearUIKitHostingBackground()
    }

    /// Sous-pages Réglages — fond opaque pour un push NavigationStack propre
    /// (évite hub + détail visibles en même temps pendant l’animation).
    func processSettingsDetailPage() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                ProcessScreenBackground()
            }
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    /// Fond semi-transparent — la page sous-jacente reste visible (paramètres depuis l'accueil).
    func processTranslucentOverlayBackground() -> some View {
        ZStack {
            self
        }
        .background {
            ProcessTranslucentOverlayBackground()
        }
        .processClearUIKitHostingBackground()
    }

    /// Les pages présentées dessinent déjà leur propre fond avec
    /// `processAppPageBackground`. La surface UIKit reste transparente pour
    /// éviter de rasteriser une seconde copie plein écran du dégradé.
    @ViewBuilder
    func processAppPresentationBackground() -> some View {
        if #available(iOS 16.4, *) {
            presentationBackground(.clear)
        } else {
            self
        }
    }
}
