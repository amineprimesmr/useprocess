import Combine
import CoreMotion
import SwiftUI

/// Inclinaison 3D pilotée par le gyroscope (même rendu que la carte parrainage profil).
struct ProcessMotionTiltImageCard: View {
    let imageName: String
    var cornerRadius: CGFloat = 14

    @StateObject private var motion = ProcessDeviceMotionTiltModel()

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(cardShape)
            .offset(x: motion.parallaxX, y: motion.parallaxY)
            .rotation3DEffect(
                .degrees(motion.tiltX),
                axis: (x: 1, y: 0, z: 0),
                anchor: .center,
                perspective: 0.55
            )
            .rotation3DEffect(
                .degrees(motion.tiltY),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.55
            )
            .shadow(
                color: .black.opacity(motion.isEngaged ? 0.22 : 0.14),
                radius: motion.isEngaged ? 20 : 14,
                x: motion.parallaxX * 0.35,
                y: motion.parallaxY * 0.45 + 10
            )
            .onAppear { motion.start() }
            .onDisappear { motion.stop() }
            .accessibilityLabel("Carte repas")
            .accessibilityHint("Bouge ton téléphone pour voir l’effet 3D")
    }
}

@MainActor
final class ProcessDeviceMotionTiltModel: ObservableObject {
    @Published var tiltX: Double = 0
    @Published var tiltY: Double = 0
    @Published var parallaxX: CGFloat = 0
    @Published var parallaxY: CGFloat = 0
    @Published var isEngaged = false

    private let motionManager = CMMotionManager()
    private let maxTiltDegrees: Double
    private let maxParallax: CGFloat
    private let tiltGain: Double
    private let smoothing: Double = 0.16
    private var isRunning = false

    init(
        maxTiltDegrees: Double = 13,
        maxParallax: CGFloat = 9,
        tiltGain: Double = 2.4
    ) {
        self.maxTiltDegrees = maxTiltDegrees
        self.maxParallax = maxParallax
        self.tiltGain = tiltGain
    }

    func start() {
        guard !isRunning, motionManager.isDeviceMotionAvailable else { return }
        isRunning = true
        motionManager.deviceMotionUpdateInterval = 1 / 60
        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: .main
        ) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.apply(motion)
        }
    }

    func stop() {
        guard isRunning else { return }
        motionManager.stopDeviceMotionUpdates()
        isRunning = false
        isEngaged = false
        withAnimation(.spring(response: 0.52, dampingFraction: 0.74)) {
            tiltX = 0
            tiltY = 0
            parallaxX = 0
            parallaxY = 0
        }
    }

    private func apply(_ motion: CMDeviceMotion) {
        let gx = motion.gravity.x
        let gz = motion.gravity.z

        let targetTiltY = clamp(Double(gx) * maxTiltDegrees * tiltGain, max: maxTiltDegrees)
        let targetTiltX = clamp(Double(gz) * maxTiltDegrees * tiltGain, max: maxTiltDegrees)
        let targetParallaxX = CGFloat(gx) * maxParallax
        let targetParallaxY = CGFloat(gz) * maxParallax * 0.55

        tiltY = smooth(tiltY, targetTiltY)
        tiltX = smooth(tiltX, targetTiltX)
        parallaxX = smooth(parallaxX, targetParallaxX)
        parallaxY = smooth(parallaxY, targetParallaxY)

        let engaged = abs(gx) > 0.04 || abs(gz) > 0.04
        if engaged != isEngaged {
            isEngaged = engaged
        }
    }

    private func smooth(_ current: Double, _ target: Double) -> Double {
        current + (target - current) * smoothing
    }

    private func smooth(_ current: CGFloat, _ target: CGFloat) -> CGFloat {
        current + (target - current) * CGFloat(smoothing)
    }

    private func clamp(_ value: Double, max maxValue: Double) -> Double {
        min(maxValue, max(-maxValue, value))
    }
}
