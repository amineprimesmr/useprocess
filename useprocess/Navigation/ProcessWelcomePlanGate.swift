import SwiftUI
import UIKit

// MARK: - Section lock (blur + overlay)

private struct WelcomePlanSectionGateModifier: ViewModifier {
    let isLocked: Bool
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .blur(radius: isLocked ? 14 : 0)
            .allowsHitTesting(!isLocked)
            .overlay {
                if isLocked {
                    ZStack {
                        Color.black.opacity(theme.isDark ? 0.52 : 0.38)
                        VStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 22, weight: .semibold))
                            Text("Termine la configuration\ndu Protocole Origine")
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 24)
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    /// Floute et bloque une section tant que le questionnaire Protocole Origine n'est pas terminé.
    func welcomePlanSectionGate(isLocked: Bool) -> some View {
        modifier(WelcomePlanSectionGateModifier(isLocked: isLocked))
    }
}

// MARK: - TabView paging off

private struct ProcessMainTabSwipeDisabler: UIViewRepresentable {
    let disabled: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            Self.apply(disabled: disabled, from: uiView)
        }
    }

    private static func apply(disabled: Bool, from view: UIView) {
        guard let scrollView = pagingScrollView(startingFrom: view) else { return }
        scrollView.isScrollEnabled = !disabled
        scrollView.bounces = !disabled
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
    /// Désactive le swipe horizontal du TabView page tant que le gate est actif.
    func processMainTabSwipeDisabled(_ disabled: Bool) -> some View {
        background(ProcessMainTabSwipeDisabler(disabled: disabled))
    }
}
