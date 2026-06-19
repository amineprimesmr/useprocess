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
