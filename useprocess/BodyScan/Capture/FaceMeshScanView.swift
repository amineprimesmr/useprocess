import ARKit
import SceneKit
import SwiftUI
import UIKit

/// Scan visage TrueDepth — mesh 3D, ticks yaw relatifs (style Face ID).
struct FaceMeshScanView: UIViewRepresentable {
    @Binding var progress: Double
    @Binding var ringProgress: Double
    @Binding var activeTickSectors: Set<Int>
    @Binding var instruction: String
    @Binding var frameHint: String?
    @Binding var isFaceDetected: Bool
    @Binding var isDeviceSupported: Bool
    var onComplete: (FaceScanCapturePayload) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            progress: $progress,
            ringProgress: $ringProgress,
            activeTickSectors: $activeTickSectors,
            instruction: $instruction,
            frameHint: $frameHint,
            isFaceDetected: $isFaceDetected,
            isDeviceSupported: $isDeviceSupported,
            onComplete: onComplete
        )
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.delegate = context.coordinator
        view.session.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        view.scene = SCNScene()
        view.backgroundColor = .black
        view.rendersCameraGrain = false
        view.preferredFramesPerSecond = 60
        context.coordinator.arView = view

        guard ARFaceTrackingConfiguration.isSupported else {
            DispatchQueue.main.async {
                context.coordinator.isDeviceSupported = false
                instruction = "Face ID nécessite un iPhone avec capteur TrueDepth."
                frameHint = nil
                isFaceDetected = false
                progress = 0
                ringProgress = 0
                activeTickSectors = []
            }
            return view
        }

        DispatchQueue.main.async {
            context.coordinator.isDeviceSupported = true
        }

        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.maximumNumberOfTrackedFaces = 1
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
        coordinator.arView = nil
        coordinator.faceNode = nil
    }

    final class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        @Binding var progress: Double
        @Binding var ringProgress: Double
        @Binding var activeTickSectors: Set<Int>
        @Binding var instruction: String
        @Binding var frameHint: String?
        @Binding var isFaceDetected: Bool
        @Binding var isDeviceSupported: Bool
        let onComplete: (FaceScanCapturePayload) -> Void

        weak var arView: ARSCNView?
        weak var faceNode: SCNNode?

        let scanDuration: TimeInterval = 5.5
        let tickCount = 72
        let minSectorsToComplete = 24
        /// Amplitude typique d’un mouvement de tête Face ID (~35°).
        let maxHeadRotation: Float = 0.62
        var completed = false
        var scanStartTime: Date?
        var trackedFrameCount = 0
        var faceDetected = false
        var lostFrameStreak = 0

        var sampledMeshes: [FaceMesh3DData] = []
        var filledTickSectors = Set<Int>()
        var blendShapeAccumulators: [String: (sum: Float, count: Int)] = [:]
        var bestSnapshot: UIImage?

        private var referenceTransform: simd_float4x4?
        private var lastSector: Int?
        private var lastPublishedSectorSignature = 0
        private var lastUIUpdate: CFTimeInterval = 0
        private let uiUpdateMinInterval: CFTimeInterval = 1.0 / 30.0

        init(
            progress: Binding<Double>,
            ringProgress: Binding<Double>,
            activeTickSectors: Binding<Set<Int>>,
            instruction: Binding<String>,
            frameHint: Binding<String?>,
            isFaceDetected: Binding<Bool>,
            isDeviceSupported: Binding<Bool>,
            onComplete: @escaping (FaceScanCapturePayload) -> Void
        ) {
            _progress = progress
            _ringProgress = ringProgress
            _activeTickSectors = activeTickSectors
            _instruction = instruction
            _frameHint = frameHint
            _isFaceDetected = isFaceDetected
            _isDeviceSupported = isDeviceSupported
            self.onComplete = onComplete
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            DispatchQueue.main.async {
                self.instruction = "Erreur caméra — réessayez."
                self.frameHint = nil
            }
        }

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard anchor is ARFaceAnchor,
                  let sceneView = renderer as? ARSCNView,
                  let device = sceneView.device else { return nil }

            let geometry = ARSCNFaceGeometry(device: device)!
            geometry.firstMaterial?.fillMode = .lines
            geometry.firstMaterial?.diffuse.contents = UIColor(
                red: 0.20, green: 0.84, blue: 1.0, alpha: 0.9
            )
            geometry.firstMaterial?.lightingModel = .constant
            geometry.firstMaterial?.isDoubleSided = true

            let node = SCNNode(geometry: geometry)
            faceNode = node
            return node
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let geometry = node.geometry as? ARSCNFaceGeometry else { return }
            geometry.update(from: faceAnchor.geometry)
            guard !completed else { return }
            process(faceAnchor: faceAnchor)
        }

        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            guard anchors.contains(where: { $0 is ARFaceAnchor }) else { return }
            markFaceLost(force: true)
        }

        private func markFaceLost(force: Bool = false) {
            guard !completed else { return }

            if force {
                lostFrameStreak = 12
            } else {
                lostFrameStreak += 1
                guard lostFrameStreak >= 12 else { return }
            }

            guard faceDetected || scanStartTime != nil else { return }
            resetScanTracking()
            publishUI(force: true) {
                self.isFaceDetected = false
                self.progress = 0
                self.ringProgress = 0
                self.activeTickSectors = []
                self.instruction = "Placez votre visage dans le cadre."
                self.frameHint = nil
            }
        }

        private func resetScanTracking() {
            faceDetected = false
            trackedFrameCount = 0
            lostFrameStreak = 0
            scanStartTime = nil
            referenceTransform = nil
            lastSector = nil
            filledTickSectors.removeAll()
            lastPublishedSectorSignature = 0
        }

        private func beginScan(with faceAnchor: ARFaceAnchor) {
            scanStartTime = Date()
            referenceTransform = faceAnchor.transform
            let startSector = sectorIndex(for: faceAnchor.transform)
            lastSector = startSector
            filledTickSectors.insert(startSector)
            for offset in -1...1 {
                filledTickSectors.insert((startSector + offset + tickCount) % tickCount)
            }
            publishUI(force: true) {
                HapticManager.shared.impact(.soft)
                self.isFaceDetected = true
                self.instruction = "Bougez lentement la tête pour compléter le cercle."
                self.frameHint = nil
            }
        }

        private func process(faceAnchor: ARFaceAnchor) {
            guard faceAnchor.isTracked else {
                markFaceLost(force: false)
                return
            }

            lostFrameStreak = 0
            faceDetected = true
            trackedFrameCount += 1

            let z = faceAnchor.transform.columns.3.z
            if let hint = distanceHint(z: z), scanStartTime == nil {
                publishUI(force: false) {
                    self.isFaceDetected = self.trackedFrameCount >= 4
                    self.frameHint = hint
                    self.instruction = "Ajustez la distance avec l’iPhone."
                }
                return
            }

            if scanStartTime == nil, trackedFrameCount >= 5 {
                beginScan(with: faceAnchor)
            }

            guard scanStartTime != nil, referenceTransform != nil else {
                publishUI(force: false) {
                    self.isFaceDetected = true
                    self.instruction = "Placez votre visage dans le cadre."
                }
                return
            }

            registerHeadPose(from: faceAnchor.transform)
            accumulateBlendShapes(faceAnchor.blendShapes)

            guard let scanStart = scanStartTime else { return }
            let elapsed = Date().timeIntervalSince(scanStart)
            let tickProgress = Double(filledTickSectors.count) / Double(tickCount)
            let timeProgress = min(1, elapsed / scanDuration)
            let combined = min(1, tickProgress * 0.75 + timeProgress * 0.25)

            if elapsed > 0.25, sampledMeshes.count < 40 {
                sampledMeshes.append(extractMesh(from: faceAnchor.geometry))
                if Int(elapsed * 2) % 2 == 0, let snap = arView?.snapshot() {
                    bestSnapshot = snap
                }
            }

            let instructionText: String
            if tickProgress < 0.45 {
                instructionText = "Bougez lentement la tête pour compléter le cercle."
            } else if combined < 0.92 {
                instructionText = "Presque terminé…"
            } else {
                instructionText = "Finalisation du scan…"
            }

            let sectorSignature = filledTickSectors.reduce(0) { $0 ^ ($1 &* 31) }
            let sectorsChanged = sectorSignature != lastPublishedSectorSignature
            publishUI(
                ring: tickProgress,
                progress: combined,
                force: sectorsChanged
            ) {
                self.isFaceDetected = true
                self.frameHint = nil
                self.activeTickSectors = self.filledTickSectors
                self.instruction = instructionText
                if sectorsChanged {
                    HapticManager.shared.selection()
                    self.lastPublishedSectorSignature = sectorSignature
                }
            }

            let best = sampledMeshes.max(by: { $0.vertices.count < $1.vertices.count }) ?? .empty
            let hasSolidMesh = best.isValid && best.vertices.count >= 200

            if filledTickSectors.count >= minSectorsToComplete,
               tickProgress >= 0.33,
               elapsed >= scanDuration * 0.65,
               hasSolidMesh,
               !completed {
                finishScan(bestMesh: best)
            }
        }

        private func finishScan(bestMesh: FaceMesh3DData) {
            completed = true
            let shapes = blendShapeAccumulators.mapValues { $0.sum / Float($0.count) }
            let payload = FaceScanCapturePayload(
                mesh: bestMesh,
                snapshot: bestSnapshot ?? arView?.snapshot(),
                averageBlendShapes: shapes,
                yawCoverage: Double(filledTickSectors.count) / Double(tickCount)
            )
            publishUI(force: true) {
                self.progress = 1
                self.ringProgress = 1
                self.activeTickSectors = Set(0..<self.tickCount)
                self.instruction = "Première analyse\nFace ID terminée."
                self.frameHint = nil
                HapticManager.shared.notification(.success)
                self.onComplete(payload)
            }
        }

        // MARK: - Pose → secteurs (yaw/pitch relatifs au neutre, style Face ID)

        private func relativeAngles(from transform: simd_float4x4) -> SIMD2<Float> {
            guard let ref = referenceTransform else { return .zero }
            let rel = simd_mul(simd_inverse(ref), transform)
            let q = simd_quaternion(rel)
            let x = q.vector.x
            let y = q.vector.y
            let z = q.vector.z
            let w = q.vector.w

            let sinPitch = 2 * (w * x - y * z)
            let pitch = asin(max(-1, min(1, sinPitch)))
            let sinYaw = 2 * (w * y + x * z)
            let cosYaw = 1 - 2 * (x * x + y * y)
            let yaw = atan2(sinYaw, cosYaw)
            return SIMD2(pitch, yaw)
        }

        /// Index 0 = haut (pitch +), sens horaire. Combine yaw et pitch sur le cercle.
        private func sectorIndex(for transform: simd_float4x4) -> Int {
            let angles = relativeAngles(from: transform)
            let pitch = angles.x
            let yaw = angles.y

            let nx = max(-1, min(1, yaw / maxHeadRotation))
            let ny = max(-1, min(1, pitch / maxHeadRotation))
            let circleAngle = atan2(nx, ny)

            var t = (circleAngle + Float.pi) / (2 * Float.pi)
            if t >= 1 { t -= 1 }
            if t < 0 { t += 1 }
            return Int(t * Float(tickCount)) % tickCount
        }

        private func registerHeadPose(from transform: simd_float4x4) {
            let sector = sectorIndex(for: transform)

            if let last = lastSector, last != sector {
                fillShortestArc(from: last, to: sector)
            }
            lastSector = sector

            for offset in -3...3 {
                filledTickSectors.insert((sector + offset + tickCount) % tickCount)
            }
        }

        private func fillShortestArc(from: Int, to: Int) {
            guard from != to else { return }
            let n = tickCount
            var forward = (to - from + n) % n
            let backward = (from - to + n) % n

            if forward <= backward {
                var idx = from
                for _ in 0...forward {
                    filledTickSectors.insert(idx)
                    idx = (idx + 1) % n
                }
            } else {
                var idx = from
                for _ in 0...backward {
                    filledTickSectors.insert(idx)
                    idx = (idx - 1 + n) % n
                }
            }
        }

        private func publishUI(
            ring: Double? = nil,
            progress: Double? = nil,
            force: Bool,
            _ block: @escaping () -> Void
        ) {
            let now = CACurrentMediaTime()
            if !force, now - lastUIUpdate < uiUpdateMinInterval { return }
            lastUIUpdate = now

            DispatchQueue.main.async {
                if let ring { self.ringProgress = ring }
                if let progress { self.progress = progress }
                block()
            }
        }

        private func publishUI(force: Bool, _ block: @escaping () -> Void) {
            publishUI(ring: nil, progress: nil, force: force, block)
        }

        private func accumulateBlendShapes(_ shapes: [ARFaceAnchor.BlendShapeLocation: NSNumber]) {
            let keys: [ARFaceAnchor.BlendShapeLocation] = [
                .jawOpen, .mouthFrownLeft, .mouthFrownRight,
                .eyeSquintLeft, .eyeSquintRight, .cheekPuff,
                .mouthSmileLeft, .mouthSmileRight, .browDownLeft, .browDownRight
            ]
            for key in keys {
                guard let value = shapes[key]?.floatValue else { continue }
                let name = key.rawValue
                var entry = blendShapeAccumulators[name] ?? (0, 0)
                entry.sum += value
                entry.count += 1
                blendShapeAccumulators[name] = entry
            }
        }

        private func distanceHint(z: Float) -> String? {
            if z > -0.15 { return "Éloignez un peu l’iPhone" }
            if z < -0.75 { return "Rapprochez l’iPhone de votre visage" }
            return nil
        }

        private func extractMesh(from geometry: ARFaceGeometry) -> FaceMesh3DData {
            var vertices: [Float] = []
            vertices.reserveCapacity(geometry.vertices.count * 3)
            for v in geometry.vertices {
                vertices.append(v.x)
                vertices.append(v.y)
                vertices.append(v.z)
            }

            var textureCoordinates: [Float] = []
            textureCoordinates.reserveCapacity(geometry.textureCoordinates.count * 2)
            for t in geometry.textureCoordinates {
                textureCoordinates.append(t.x)
                textureCoordinates.append(t.y)
            }

            return FaceMesh3DData(
                vertices: vertices,
                triangleIndices: geometry.triangleIndices.map { Int($0) },
                textureCoordinates: textureCoordinates
            )
        }
    }
}
