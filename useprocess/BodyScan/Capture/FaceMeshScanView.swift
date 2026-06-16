import ARKit
import SceneKit
import SwiftUI
import UIKit

/// Scan visage TrueDepth — mesh 3D, validation stricte, flash écran si faible luminosité.
struct FaceMeshScanView: UIViewRepresentable {
    @Binding var progress: Double
    @Binding var ringProgress: Double
    @Binding var activeTickSectors: Set<Int>
    @Binding var instruction: String
    @Binding var frameHint: String?
    @Binding var isFaceDetected: Bool
    @Binding var isDeviceSupported: Bool
    @Binding var isLowLight: Bool
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
            isLowLight: $isLowLight,
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
        Task { @MainActor in
            FaceScanScreenFlash.shared.activate(animated: false)
        }
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
        coordinator.arView = nil
        coordinator.faceNode = nil
        Task { @MainActor in
            FaceScanScreenFlash.shared.deactivate()
        }
    }

    final class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        @Binding var progress: Double
        @Binding var ringProgress: Double
        @Binding var activeTickSectors: Set<Int>
        @Binding var instruction: String
        @Binding var frameHint: String?
        @Binding var isFaceDetected: Bool
        @Binding var isDeviceSupported: Bool
        @Binding var isLowLight: Bool
        let onComplete: (FaceScanCapturePayload) -> Void

        weak var arView: ARSCNView?
        weak var faceNode: SCNNode?

        let scanDuration: TimeInterval = 7.0
        let tickCount = 72
        let minSectorsToComplete = 48
        let minTickProgress = 0.62
        let maxHeadRotation: Float = 0.62
        let minTrackedFramesBeforeScan = 12

        var completed = false
        var scanStartTime: Date?
        var trackedFrameCount = 0
        var faceDetected = false
        var lostFrameStreak = 0
        var currentAmbientIntensity: CGFloat = 1000
        var qualityRetryCount = 0

        var activeScanId = UUID().uuidString
        let videoRecorder = FaceScanVideoRecorder()

        var sampledMeshes: [FaceMesh3DData] = []
        var filledTickSectors = Set<Int>()
        var blendShapeAccumulators: [String: (sum: Float, count: Int)] = [:]
        var angleSamples: [SIMD2<Float>] = []
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
            isLowLight: Binding<Bool>,
            onComplete: @escaping (FaceScanCapturePayload) -> Void
        ) {
            _progress = progress
            _ringProgress = ringProgress
            _activeTickSectors = activeTickSectors
            _instruction = instruction
            _frameHint = frameHint
            _isFaceDetected = isFaceDetected
            _isDeviceSupported = isDeviceSupported
            _isLowLight = isLowLight
            self.onComplete = onComplete
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard !completed else { return }
            let intensity = frame.lightEstimate?.ambientIntensity ?? 1000
            currentAmbientIntensity = intensity
            let low = FaceScanQualityValidator.isLowLight(ambientIntensity: intensity)

            if scanStartTime != nil {
                videoRecorder.append(frame: frame)
            }

            DispatchQueue.main.async {
                self.isLowLight = low
                FaceScanScreenFlash.shared.refreshMaximum()
            }
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
                lostFrameStreak = 15
            } else {
                lostFrameStreak += 1
                guard lostFrameStreak >= 15 else { return }
            }

            guard faceDetected || scanStartTime != nil else { return }
            resetScanTracking()
            publishUI(force: true) {
                self.isFaceDetected = false
                self.progress = 0
                self.ringProgress = 0
                self.activeTickSectors = []
                self.instruction = "Place ton visage dans le cadre."
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
            angleSamples.removeAll()
            sampledMeshes.removeAll()
            blendShapeAccumulators.removeAll()
            bestSnapshot = nil
            lastPublishedSectorSignature = 0
            videoRecorder.cancel()
            activeScanId = UUID().uuidString
        }

        private func beginScan(with faceAnchor: ARFaceAnchor) {
            activeScanId = UUID().uuidString
            videoRecorder.start(at: videoRecorder.prepareOutputURL(scanId: activeScanId))
            scanStartTime = Date()
            referenceTransform = faceAnchor.transform
            let startSector = sectorIndex(for: faceAnchor.transform)
            lastSector = startSector
            filledTickSectors.insert(startSector)
            angleSamples.append(relativeAngles(from: faceAnchor.transform))

            Task { @MainActor in
                FaceScanScreenFlash.shared.activate(animated: false)
            }

            publishUI(force: true) {
                HapticManager.shared.impact(.soft)
                self.isFaceDetected = true
                self.instruction = "Tourne lentement la tête pour compléter le cercle."
                self.frameHint = self.isLowLight
                    ? "Flash écran activé — garde le visage centré"
                    : "Éclairage écran au maximum"
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
                    self.isFaceDetected = self.trackedFrameCount >= self.minTrackedFramesBeforeScan
                    self.frameHint = hint
                    self.instruction = "Ajuste la distance avec l'iPhone."
                }
                return
            }

            if scanStartTime == nil {
                if trackedFrameCount >= minTrackedFramesBeforeScan {
                    if isLowLight || FaceScanQualityValidator.isLowLight(ambientIntensity: currentAmbientIntensity) {
                        publishUI(force: false) {
                            self.isFaceDetected = true
                            self.instruction = "Environnement sombre — flash activé."
                            self.frameHint = "Place ton visage face à l'écran."
                        }
                    }
                    beginScan(with: faceAnchor)
                } else {
                    publishUI(force: false) {
                        self.isFaceDetected = self.trackedFrameCount >= 4
                        self.instruction = "Place ton visage dans le cadre."
                    }
                }
                return
            }

            guard referenceTransform != nil else { return }

            registerHeadPose(from: faceAnchor.transform)
            accumulateBlendShapes(faceAnchor.blendShapes)

            guard let scanStart = scanStartTime else { return }
            let elapsed = Date().timeIntervalSince(scanStart)
            let tickProgress = Double(filledTickSectors.count) / Double(tickCount)

            if elapsed > 0.4, sampledMeshes.count < 50 {
                sampledMeshes.append(extractMesh(from: faceAnchor.geometry))
                if let snap = arView?.snapshot() {
                    if bestSnapshot == nil
                        || FaceScanQualityValidator.averageLuminance(of: snap)
                        > FaceScanQualityValidator.averageLuminance(of: bestSnapshot!) {
                        bestSnapshot = snap
                    }
                }
            }

            let instructionText: String
            if tickProgress < 0.35 {
                instructionText = "Tourne lentement la tête — gauche, droite, haut, bas."
            } else if tickProgress < minTickProgress {
                instructionText = "Continue à tourner la tête pour compléter le cercle."
            } else if !qualityReady(elapsed: elapsed, tickProgress: tickProgress) {
                instructionText = qualityHint(elapsed: elapsed, tickProgress: tickProgress)
            } else {
                instructionText = "Finalisation du scan…"
            }

            let sectorSignature = filledTickSectors.reduce(0) { $0 ^ ($1 &* 31) }
            let sectorsChanged = sectorSignature != lastPublishedSectorSignature
            publishUI(ring: tickProgress, progress: tickProgress, force: sectorsChanged) {
                self.isFaceDetected = true
                self.activeTickSectors = self.filledTickSectors
                self.instruction = instructionText
                if sectorsChanged {
                    HapticManager.shared.selection()
                    self.lastPublishedSectorSignature = sectorSignature
                }
            }

            let best = sampledMeshes.max(by: { $0.vertices.count < $1.vertices.count }) ?? .empty

            if qualityReady(elapsed: elapsed, tickProgress: tickProgress),
               FaceScanQualityValidator.meshIsSolid(best),
               !completed {
                finishScan(bestMesh: best)
            } else if elapsed >= scanDuration * 1.15, !completed {
                handleQualityFailure()
            }
        }

        private func qualityReady(elapsed: TimeInterval, tickProgress: Double) -> Bool {
            guard elapsed >= scanDuration * 0.85 else { return false }
            guard tickProgress >= minTickProgress else { return false }
            guard filledTickSectors.count >= minSectorsToComplete else { return false }
            guard FaceScanQualityValidator.headSpreadIsSufficient(angleSamples) else { return false }

            let snap = bestSnapshot ?? arView?.snapshot()
            let minLuma: CGFloat = isLowLight ? 0.16 : 0.11
            return FaceScanQualityValidator.snapshotIsUsable(snap, minimumLuminance: minLuma)
        }

        private func qualityHint(elapsed: TimeInterval, tickProgress: Double) -> String {
            if tickProgress < minTickProgress {
                return "Tourne plus la tête pour remplir le cercle."
            }
            if !FaceScanQualityValidator.headSpreadIsSufficient(angleSamples) {
                return "Fais de plus grands mouvements de tête."
            }
            let snap = bestSnapshot ?? arView?.snapshot()
            if !FaceScanQualityValidator.snapshotIsUsable(snap, minimumLuminance: isLowLight ? 0.16 : 0.11) {
                return isLowLight
                    ? "Trop sombre — rapproche-toi de l'écran éclairé."
                    : "Image trop sombre — va vers une source de lumière."
            }
            if elapsed < scanDuration * 0.85 {
                return "Encore quelques secondes…"
            }
            return "Finalisation…"
        }

        private func handleQualityFailure() {
            qualityRetryCount += 1
            if qualityRetryCount >= 3 {
                publishUI(force: true) {
                    self.instruction = "Scan impossible — augmente la lumière et réessaie."
                    self.frameHint = "Quitte puis relance le scan."
                }
                return
            }
            resetScanTracking()
            publishUI(force: true) {
                self.progress = 0
                self.ringProgress = 0
                self.activeTickSectors = []
                self.instruction = "Qualité insuffisante — recommence en bougeant la tête."
                self.frameHint = self.isLowLight ? "Flash écran activé" : "Cherche plus de lumière."
                HapticManager.shared.notification(.warning)
            }
        }

        private func finishScan(bestMesh: FaceMesh3DData) {
            completed = true
            let shapes = blendShapeAccumulators.mapValues { $0.sum / Float($0.count) }
            let scanId = activeScanId
            let snapshot = bestSnapshot ?? arView?.snapshot()

            Task {
                let videoURL = await videoRecorder.finish()
                let videoFilename: String?
                if let videoURL, FileManager.default.fileExists(atPath: videoURL.path) {
                    videoFilename = "\(scanId)_face.mp4"
                } else {
                    videoFilename = nil
                }

                let payload = FaceScanCapturePayload(
                    scanId: scanId,
                    mesh: bestMesh,
                    snapshot: snapshot,
                    videoFilename: videoFilename,
                    averageBlendShapes: shapes,
                    yawCoverage: Double(filledTickSectors.count) / Double(tickCount)
                )

                await MainActor.run {
                    self.publishUI(force: true) {
                        self.progress = 1
                        self.ringProgress = 1
                        self.activeTickSectors = self.filledTickSectors
                        self.instruction = "Analyse terminée."
                        self.frameHint = nil
                        HapticManager.shared.notification(.success)
                        Task { @MainActor in FaceScanScreenFlash.shared.deactivate() }
                        self.onComplete(payload)
                    }
                }
            }
        }

        // MARK: - Pose → secteurs (strict)

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

        private func sectorIndex(for transform: simd_float4x4) -> Int {
            let angles = relativeAngles(from: transform)
            let pitch = angles.x
            let yaw = angles.y

            let nx = max(-1, min(1, -yaw / maxHeadRotation))
            let ny = max(-1, min(1, pitch / maxHeadRotation))
            let circleAngle = atan2(nx, ny)

            var t = (circleAngle + Float.pi) / (2 * Float.pi)
            if t >= 1 { t -= 1 }
            if t < 0 { t += 1 }
            return Int(t * Float(tickCount)) % tickCount
        }

        private func registerHeadPose(from transform: simd_float4x4) {
            let sector = sectorIndex(for: transform)
            let angles = relativeAngles(from: transform)
            angleSamples.append(angles)
            if angleSamples.count > 150 { angleSamples.removeFirst() }

            guard let last = lastSector else {
                filledTickSectors.insert(sector)
                lastSector = sector
                return
            }

            guard sector != last else { return }

            let forward = (sector - last + tickCount) % tickCount
            let backward = (last - sector + tickCount) % tickCount

            if forward <= backward {
                guard forward <= 3 else { return }
                for step in 1...forward {
                    filledTickSectors.insert((last + step) % tickCount)
                }
            } else {
                guard backward <= 3 else { return }
                for step in 1...backward {
                    filledTickSectors.insert((last - step + tickCount) % tickCount)
                }
            }
            lastSector = sector
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
            if z > -0.15 { return "Éloigne un peu l'iPhone" }
            if z < -0.75 { return "Rapproche l'iPhone de ton visage" }
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
