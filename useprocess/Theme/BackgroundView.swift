import SwiftUI
import UIKit

/// Tokens du fond app — dégradé bleu / violet en clair, fond uni en sombre.
enum ProcessBackgroundPalette {
    static let lightBase = Color(red: 0.968, green: 0.972, blue: 0.988)
    static let lightBlueGlow = Color(red: 0.62, green: 0.80, blue: 1.0)
    static let lightVioletGlow = Color(red: 0.78, green: 0.70, blue: 0.98)

    static let darkBase = Color(red: 0.07, green: 0.08, blue: 0.11)
}

/// Fond principal de l’app — dégradé subtil bleu / violet en clair, plat en sombre.
struct ProcessScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var usesLightGradient: Bool {
        colorScheme != .dark
    }

    var body: some View {
        Group {
            if usesLightGradient {
                lightGradientBackground
            } else {
                ProcessBackgroundPalette.darkBase
            }
        }
        .ignoresSafeArea()
    }

    private var lightGradientBackground: some View {
        ZStack {
            ProcessBackgroundPalette.lightBase

            // Accents supérieurs discrets (coins — pas le focus principal).
            RadialGradient(
                colors: [
                    ProcessBackgroundPalette.lightBlueGlow.opacity(0.26),
                    ProcessBackgroundPalette.lightBlueGlow.opacity(0.07),
                    .clear
                ],
                center: UnitPoint(x: 0.10, y: 0.10),
                startRadius: 0,
                endRadius: 300
            )

            RadialGradient(
                colors: [
                    ProcessBackgroundPalette.lightVioletGlow.opacity(0.24),
                    ProcessBackgroundPalette.lightVioletGlow.opacity(0.06),
                    .clear
                ],
                center: UnitPoint(x: 0.90, y: 0.09),
                startRadius: 0,
                endRadius: 280
            )

            // Cœur — centre de l'écran (zone repas / contenu principal).
            RadialGradient(
                colors: [
                    ProcessBackgroundPalette.lightBlueGlow.opacity(0.40),
                    ProcessBackgroundPalette.lightBlueGlow.opacity(0.14),
                    ProcessBackgroundPalette.lightVioletGlow.opacity(0.06),
                    .clear
                ],
                center: UnitPoint(x: 0.46, y: 0.54),
                startRadius: 16,
                endRadius: 520
            )

            RadialGradient(
                colors: [
                    ProcessBackgroundPalette.lightVioletGlow.opacity(0.36),
                    ProcessBackgroundPalette.lightVioletGlow.opacity(0.12),
                    .clear
                ],
                center: UnitPoint(x: 0.58, y: 0.50),
                startRadius: 8,
                endRadius: 460
            )

            // Bas de page — bloom harmonisé sous le carousel / tab bar.
            RadialGradient(
                colors: [
                    ProcessBackgroundPalette.lightVioletGlow.opacity(0.34),
                    ProcessBackgroundPalette.lightBlueGlow.opacity(0.20),
                    ProcessBackgroundPalette.lightBlueGlow.opacity(0.06),
                    .clear
                ],
                center: UnitPoint(x: 0.50, y: 0.92),
                startRadius: 0,
                endRadius: 440
            )

            // Liaison verticale — teinte progressive vers le milieu et le bas.
            LinearGradient(
                colors: [
                    Color.white.opacity(0.42),
                    ProcessBackgroundPalette.lightBlueGlow.opacity(0.10),
                    ProcessBackgroundPalette.lightVioletGlow.opacity(0.24),
                    ProcessBackgroundPalette.lightVioletGlow.opacity(0.12)
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.0),
                endPoint: UnitPoint(x: 0.5, y: 1.0)
            )
        }
    }
}

/// Alias historique — même fond que `ProcessScreenBackground`.
struct BackgroundView: View {
    var body: some View {
        ProcessScreenBackground()
    }
}

/// Force les UIScrollView / UINavigationController parents à rester transparents (TabView + NavigationStack).
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
                && size.height >= UIScreen.main.bounds.height * 0.5
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

    /// Fond page plein écran — même dégradé que l’accueil + transparence navigation/scroll.
    func processAppPageBackground() -> some View {
        ZStack {
            ProcessScreenBackground()
            self
        }
        .processClearUIKitHostingBackground()
    }

    /// Sheets / covers — dégradé clair identique à l’accueil.
    @ViewBuilder
    func processAppPresentationBackground() -> some View {
        if #available(iOS 16.4, *) {
            presentationBackground {
                ProcessScreenBackground()
            }
        } else {
            self
        }
    }
}
