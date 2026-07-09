import Combine
import CoreMotion
import Foundation

/// Gyro → roulis / tangage lissés pour la surface d'eau (−1…1).
@MainActor
final class ProcessFluidWaterMotionEngine: ObservableObject {
    /// −1 = eau vers la gauche, +1 = eau vers la droite.
    @Published private(set) var roll: CGFloat = 0
    /// −1 = niveau plus bas, +1 = niveau plus haut.
    @Published private(set) var pitch: CGFloat = 0
    @Published private(set) var wavePhase: CGFloat = 0

    private let motionManager = CMMotionManager()
    private var isRunning = false

    private let smoothing: CGFloat = 0.22
    private let deadZone: CGFloat = 0.025

    func start() {
        guard !isRunning, motionManager.isDeviceMotionAvailable else { return }
        isRunning = true
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        // Même référence que ProcessMotionTiltImageCard (déjà fiable dans l'app).
        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: .main
        ) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.consumeMotion(motion)
        }
    }

    func stop() {
        guard isRunning else { return }
        motionManager.stopDeviceMotionUpdates()
        isRunning = false
        roll = 0
        pitch = 0
        wavePhase = 0
    }

    func bumpWave() {
        wavePhase += 0.4
    }

    private func consumeMotion(_ motion: CMDeviceMotion) {
        let gx = CGFloat(motion.gravity.x)
        let gy = CGFloat(motion.gravity.y)
        let gz = CGFloat(motion.gravity.z)

        // Portrait : gy ≈ −1. Roulis = inclinaison latérale pure.
        let vertical = max(0.35, abs(gy))
        var nextRoll = max(-1, min(1, gx / vertical))
        // Tangage relatif au téléphone à peu près droit (gz ≈ 0 en portrait).
        var nextPitch = max(-1, min(1, gz / 0.85))

        if abs(nextRoll) < deadZone { nextRoll = 0 }
        if abs(nextPitch) < deadZone { nextPitch = 0 }

        roll = roll + (nextRoll - roll) * smoothing
        pitch = pitch + (nextPitch - pitch) * smoothing
    }
}
