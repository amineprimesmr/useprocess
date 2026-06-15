import UIKit

/// Flash écran avant (style Snap / TikTok) — luminosité max + restauration à la sortie.
@MainActor
final class FaceScanScreenFlash {
    static let shared = FaceScanScreenFlash()

    private var savedBrightness: CGFloat?
    private(set) var isActive = false

    private init() {}

    /// Monte la luminosité à 100 % immédiatement (utilisé pendant tout le scan visage).
    func activate(animated: Bool = false) {
        if savedBrightness == nil {
            savedBrightness = UIScreen.main.brightness
        }
        isActive = true
        setBrightness(1.0, animated: animated)
    }

    /// Ré-applique le max si iOS ou l'utilisateur a baissé la luminosité pendant le scan.
    func refreshMaximum() {
        guard isActive else { return }
        UIScreen.main.brightness = 1.0
    }

    func deactivate(animated: Bool = true) {
        guard isActive else { return }
        isActive = false
        let target = savedBrightness ?? UIScreen.main.brightness
        setBrightness(target, animated: animated)
        savedBrightness = nil
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

        let steps = 8
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.02) {
                guard self.isActive || clamped < 1 else { return }
                let progress = CGFloat(step) / CGFloat(steps)
                UIScreen.main.brightness = start + delta * progress
            }
        }
    }
}
