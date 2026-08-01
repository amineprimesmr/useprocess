import Combine
import CoreGraphics
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
    private var isUserInteracting = false
    private var sensorRoll: CGFloat = 0
    private var sensorPitch: CGFloat = 0

    private let motionUpdateInterval: TimeInterval = 1.0 / 20.0
    private let publishEpsilon: CGFloat = 0.018

    private var lastPublishedRoll: CGFloat = 0
    private var lastPublishedPitch: CGFloat = 0

    private let smoothing: CGFloat = 0.22
    private let deadZone: CGFloat = 0.025

    func start() {
        guard !isRunning, motionManager.isDeviceMotionAvailable else { return }
        isRunning = true
        motionManager.deviceMotionUpdateInterval = motionUpdateInterval
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
        lastPublishedRoll = 0
        lastPublishedPitch = 0
    }

    func bumpWave() {
        wavePhase += 0.4
    }

    func beginInteraction(at location: CGPoint, in size: CGSize) {
        isUserInteracting = true
        applyInteraction(at: location, in: size, addsWave: true)
    }

    func updateInteraction(at location: CGPoint, in size: CGSize) {
        applyInteraction(at: location, in: size, addsWave: false)
    }

    func endInteraction() {
        isUserInteracting = false
        publishMotion(roll: sensorRoll, pitch: sensorPitch)
        bumpWave()
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

        sensorRoll = sensorRoll + (nextRoll - sensorRoll) * smoothing
        sensorPitch = sensorPitch + (nextPitch - sensorPitch) * smoothing

        guard !isUserInteracting else { return }
        publishMotion(roll: sensorRoll, pitch: sensorPitch)
    }

    private func publishMotion(roll newRoll: CGFloat, pitch newPitch: CGFloat) {
        guard abs(newRoll - lastPublishedRoll) > publishEpsilon
            || abs(newPitch - lastPublishedPitch) > publishEpsilon else { return }
        roll = newRoll
        pitch = newPitch
        lastPublishedRoll = newRoll
        lastPublishedPitch = newPitch
    }

    private func applyInteraction(at location: CGPoint, in size: CGSize, addsWave: Bool) {
        guard size.width > 1, size.height > 1 else { return }

        let x = min(size.width, max(0, location.x))
        let y = min(size.height, max(0, location.y))
        let normalizedX = (x / size.width - 0.5) * 2
        let normalizedY = (0.5 - y / size.height) * 2

        roll = max(-1, min(1, normalizedX))
        pitch = max(-1, min(1, normalizedY))
        lastPublishedRoll = roll
        lastPublishedPitch = pitch

        if addsWave {
            bumpWave()
        }
    }
}
