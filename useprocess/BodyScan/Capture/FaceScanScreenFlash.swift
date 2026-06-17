import UIKit

/// Flash écran avant (style Snap / TikTok) — luminosité max + restauration à la sortie.
@MainActor
final class FaceScanScreenFlash {
    static let shared = FaceScanScreenFlash()

    private var savedBrightness: CGFloat?
    private(set) var isActive = false
    private var animationGeneration = 0

    private init() {}

    /// Monte la luminosité à 100 % — idempotent, sans re-animation si déjà actif.
    func activate(animated: Bool = false) {
        if savedBrightness == nil {
            savedBrightness = UIScreen.main.brightness
        }

        if isActive {
            UIScreen.main.brightness = 1.0
            return
        }

        isActive = true
        cancelPendingAnimations()
        setBrightness(1.0, animated: animated)
    }

    func deactivate(animated: Bool = true) {
        guard isActive else { return }

        isActive = false
        cancelPendingAnimations()

        let target = savedBrightness ?? UIScreen.main.brightness
        setBrightness(target, animated: animated)
        savedBrightness = nil
    }

    private func cancelPendingAnimations() {
        animationGeneration += 1
    }

    private func setBrightness(_ value: CGFloat, animated: Bool) {
        let clamped = max(0, min(1, value))
        guard animated else {
            UIScreen.main.brightness = clamped
            return
        }

        let start = UIScreen.main.brightness
        let delta = clamped - start
        guard abs(delta) > 0.02 else {
            UIScreen.main.brightness = clamped
            return
        }

        let generation = animationGeneration
        let steps = 6
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.025) { [weak self] in
                guard let self, self.animationGeneration == generation else { return }
                guard self.isActive || clamped < 1 else { return }
                let progress = CGFloat(step) / CGFloat(steps)
                UIScreen.main.brightness = start + delta * progress
            }
        }
    }
}
