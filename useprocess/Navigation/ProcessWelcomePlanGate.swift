import SwiftUI
import UIKit

// MARK: - Section lock (blur + overlay)

private struct WelcomePlanSectionGateModifier: ViewModifier {
    let isLocked: Bool
    var onConfigure: (() -> Void)?
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .blur(radius: isLocked ? 14 : 0)
            .allowsHitTesting(!isLocked)
            .overlay {
                if isLocked {
                    ZStack {
                        Color.black.opacity(theme.isDark ? 0.52 : 0.38)
                        VStack(spacing: 14) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 22, weight: .semibold))
                            Text("Termine la configuration\ndu Protocole Origine")
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.center)
                            Text("Le coach te pose quelques questions pour débloquer Santé et Profil.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.82))

                            if let onConfigure {
                                Button {
                                    HapticManager.shared.impact(.medium)
                                    onConfigure()
                                } label: {
                                    Text("Terminer la configuration")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 12)
                                        .background(.white, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                        }
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 24)
                    }
                }
            }
    }
}

extension View {
    /// Floute et bloque une section tant que le questionnaire Protocole Origine n'est pas terminé.
    func welcomePlanSectionGate(isLocked: Bool, onConfigure: (() -> Void)? = nil) -> some View {
        modifier(WelcomePlanSectionGateModifier(isLocked: isLocked, onConfigure: onConfigure))
    }
}

// MARK: - TabView paging

private final class ProcessMainPagingPanDelegate: NSObject, UIGestureRecognizerDelegate {
    var swipeFullyDisabled = false

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !swipeFullyDisabled else { return false }
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }

        let t = pan.translation(in: pan.view)
        let v = pan.velocity(in: pan.view)

        let horizontal = max(abs(t.x), abs(v.x) * 0.015)
        let vertical = max(abs(t.y), abs(v.y) * 0.015)

        // Scroll surtout vertical → ne pas interpréter comme changement d'onglet.
        if vertical > horizontal * 1.05, vertical > 8 {
            return false
        }

        // Swipe horizontal volontaire uniquement.
        if horizontal < 14, abs(v.x) <= abs(v.y) * 1.2 || abs(v.x) < 180 {
            return false
        }

        return true
    }
}

private struct ProcessMainTabPagingConfigurator: UIViewRepresentable {
    let swipeFullyDisabled: Bool

    private static let panDelegate = ProcessMainPagingPanDelegate()

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            Self.apply(from: uiView, swipeFullyDisabled: swipeFullyDisabled)
        }
    }

    private static func apply(from view: UIView, swipeFullyDisabled: Bool) {
        guard let scrollView = pagingScrollView(startingFrom: view) else { return }
        panDelegate.swipeFullyDisabled = swipeFullyDisabled
        scrollView.isScrollEnabled = !swipeFullyDisabled
        scrollView.bounces = !swipeFullyDisabled
        scrollView.isDirectionalLockEnabled = true
        scrollView.panGestureRecognizer.delegate = panDelegate
    }

    private static func pagingScrollView(startingFrom view: UIView) -> UIScrollView? {
        var candidate: UIView? = view
        while let current = candidate {
            if let scroll = current as? UIScrollView, scroll.isPagingEnabled {
                return scroll
            }
            candidate = current.superview
        }
        return nil
    }
}

extension View {
    /// Verrouille le paging horizontal quand le geste est surtout vertical ; peut tout couper si `swipeDisabled`.
    func processMainTabPaging(swipeDisabled: Bool = false) -> some View {
        background(ProcessMainTabPagingConfigurator(swipeFullyDisabled: swipeDisabled))
    }

    /// Désactive le swipe horizontal du TabView page tant que le gate est actif.
    func processMainTabSwipeDisabled(_ disabled: Bool) -> some View {
        processMainTabPaging(swipeDisabled: disabled)
    }
}
