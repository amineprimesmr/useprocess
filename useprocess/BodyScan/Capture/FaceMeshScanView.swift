import ARKit
import SceneKit
import SwiftUI
import UIKit

/// Scan visage TrueDepth — mesh 3D invisible, flash piloté par l'écran parent.
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
        view.preferredFramesPerSecond = 30
        context.coordinator.arView = view

        guard ARFaceTrackingConfiguration.isSupported else {
            DispatchQueue.main.async {
                context.coordinator.isDeviceSupported = false
                instruction = "TrueDepth requis — utilise un appareil avec Face ID."
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

        context.coordinator.startSession(on: view)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        coordinator.tearDown()
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
        @Binding var isLowLight: Bool
        let onComplete: (FaceScanCapturePayload) -> Void

        weak var arView: ARSCNView?
        weak var faceNode: SCNNode?

        let scanDuration: TimeInterval = 5.5
        let tickCount = 72
        let minSectorsToComplete = 34
        let minTickProgress = 0.48
        let maxHeadRotation: Float = 0.55
        let minTrackedFramesBeforeScan = 8
        let minDistanceOkFramesBeforeScan = 14
        let minActivationAngle: Float = 0.06
        let maxSectorBridgeSteps = 2
        let lostFrameThresholdPositioning = 30
        let lostFrameThresholdScanning = 55

        var completed = false
        var isTornDown = false
        var scanStartTime: Date?
        var trackedFrameCount = 0
        var stableFrameCount = 0
        var distanceOkFrameCount = 0
        var faceDetected = false
        var lostFrameStreak = 0
        var currentAmbientIntensity: CGFloat = 1000
        var qualityRetryCount = 0
        var scanExhausted = false
        var sessionRecoveryAttempts = 0

        var activeScanId = UUID().uuidString
        let videoRecorder = FaceScanVideoRecorder()

        var sampledMeshes: [FaceMesh3DData] = []
        var filledTickSectors = Set<Int>()
        var blendShapeAccumulators: [String: (sum: Float, count: Int)] = [:]
        var angleSamples: [SIMD2<Float>] = []
        var bestSnapshot: UIImage?

        private var referenceTransform: simd_float4x4?
        private var lastRegisteredSector: Int?
        private var lastPublishedSectorSignature = 0
        private var lastUIUpdate: CFTimeInterval = 0
        private var lastLightUIUpdate: CFTimeInterval = 0
        private var lastProcessTime: CFTimeInterval = 0
        private var lastQualityFailureAt: Date?
        private let uiUpdateMinInterval: CFTimeInterval = 1.0 / 20.0
        private let lightUIUpdateMinInterval: CFTimeInterval = 1.0 / 15.0
        private let processMinInterval: CFTimeInterval = 1.0 / 24.0
        private var didConfigurePortraitCamera = false
        private var faceRemovalWorkItem: DispatchWorkItem?

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

        func tearDown() {
            isTornDown = true
            faceRemovalWorkItem?.cancel()
            videoRecorder.cancel()
        }

        func startSession(on view: ARSCNView) {
            let config = ARFaceTrackingConfiguration()
            config.isLightEstimationEnabled = true
            config.maximumNumberOfTrackedFaces = 1
            view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        }

        func recoverSessionIfNeeded() {
            guard !isTornDown, !completed, let view = arView else { return }
            guard sessionRecoveryAttempts < 2 else { return }
            sessionRecoveryAttempts += 1
            startSession(on: view)
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard !completed, !isTornDown else { return }
            configurePortraitCameraIfNeeded()
            let intensity = frame.lightEstimate?.ambientIntensity ?? 1000
            currentAmbientIntensity = intensity
            let low = FaceScanQualityValidator.isLowLight(ambientIntensity: intensity)

            if scanStartTime != nil {
                videoRecorder.append(frame: frame)
            }

            let now = CACurrentMediaTime()
            guard now - lastLightUIUpdate >= lightUIUpdateMinInterval else { return }
            lastLightUIUpdate = now

            DispatchQueue.main.async {
                if FaceScanScreenFlash.shared.isActive {
                    if !self.isLowLight { self.isLowLight = true }
                } else {
                    self.isLowLight = low
                }
            }
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            guard !isTornDown, !completed else { return }
            recoverSessionIfNeeded()
            DispatchQueue.main.async {
                self.instruction = "Reconnexion caméra…"
                self.frameHint = "Garde ton visage dans le cadre."
            }
        }

        func sessionWasInterrupted(_ session: ARSession) {
            guard !isTornDown, !completed else { return }
            DispatchQueue.main.async {
                self.instruction = "Scan interrompu — reprends quand tu es prêt."
                self.frameHint = nil
            }
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            guard !isTornDown, !completed else { return }
            recoverSessionIfNeeded()
        }

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard anchor is ARFaceAnchor,
                  let sceneView = renderer as? ARSCNView,
                  let device = sceneView.device else { return nil }

            let geometry = ARSCNFaceGeometry(device: device)!
            geometry.firstMaterial?.fillMode = .lines
            geometry.firstMaterial?.diffuse.contents = UIColor.clear
            geometry.firstMaterial?.lightingModel = .constant
            geometry.firstMaterial?.isDoubleSided = true

            let node = SCNNode(geometry: geometry)
            node.opacity = 0
            faceNode = node
            faceRemovalWorkItem?.cancel()
            return node
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let geometry = node.geometry as? ARSCNFaceGeometry else { return }
            geometry.update(from: faceAnchor.geometry)
            guard !completed, !isTornDown else { return }

            let now = CACurrentMediaTime()
            guard now - lastProcessTime >= processMinInterval else { return }
            lastProcessTime = now
            process(faceAnchor: faceAnchor)
        }

        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            guard anchors.contains(where: { $0 is ARFaceAnchor }) else { return }
            guard !completed, !isTornDown else { return }

            faceRemovalWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.markFaceLost(force: true)
            }
            faceRemovalWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: work)
        }

        private func configurePortraitCameraIfNeeded() {
            guard !didConfigurePortraitCamera, let view = arView else { return }
            guard let camera = view.pointOfView?.camera else { return }
            camera.fieldOfView = 38
            camera.zNear = 0.01
            camera.zFar = 2
            didConfigurePortraitCamera = true
        }

        private func markFaceLost(force: Bool = false) {
            guard !completed, !isTornDown else { return }

            if force {
                lostFrameStreak = lostFrameThreshold(scanning: scanStartTime != nil)
            } else {
                lostFrameStreak += 1
                guard lostFrameStreak >= lostFrameThreshold(scanning: scanStartTime != nil) else { return }
            }

            guard faceDetected || scanStartTime != nil else { return }

            if let scanStart = scanStartTime,
               Date().timeIntervalSince(scanStart) > 2.5,
               progressValue(elapsed: Date().timeIntervalSince(scanStart)) > 0.2 {
                publishUI(force: true) {
                    self.instruction = "Visage perdu — replace-toi dans le cadre."
                    self.frameHint = "Le scan reprend automatiquement."
                }
                resetScanTracking(soft: true)
                return
            }

            resetScanTracking(soft: false)
            publishUI(force: true) {
                self.isFaceDetected = false
                self.progress = 0
                self.ringProgress = 0
                self.activeTickSectors = []
                self.instruction = "Place ton visage dans le cadre."
                self.frameHint = nil
            }
        }

        private func lostFrameThreshold(scanning: Bool) -> Int {
            scanning ? lostFrameThresholdScanning : lostFrameThresholdPositioning
        }

        private func resetScanTracking(soft: Bool) {
            faceDetected = false
            trackedFrameCount = 0
            stableFrameCount = 0
            distanceOkFrameCount = 0
            lostFrameStreak = 0
            scanStartTime = nil
            referenceTransform = nil
            lastRegisteredSector = nil
            lastPublishedSectorSignature = 0

            if !soft {
                filledTickSectors.removeAll()
                angleSamples.removeAll()
                sampledMeshes.removeAll()
                blendShapeAccumulators.removeAll()
                bestSnapshot = nil
                videoRecorder.cancel()
                activeScanId = UUID().uuidString
            }
        }

        private func beginScan(with faceAnchor: ARFaceAnchor) {
            guard scanStartTime == nil else { return }

            activeScanId = UUID().uuidString
            videoRecorder.start(at: videoRecorder.prepareOutputURL(scanId: activeScanId))
            scanStartTime = Date()
            referenceTransform = faceAnchor.transform
            filledTickSectors.removeAll()
            lastRegisteredSector = nil
            angleSamples.append(relativeYawPitch(from: faceAnchor.transform))

            publishUI(ring: 0, progress: 0.02, force: true) {
                HapticManager.shared.impact(.soft)
                self.isFaceDetected = true
                self.instruction = "Tourne lentement la tête pour compléter le cercle."
                self.frameHint = nil
                self.activeTickSectors = []
                self.ringProgress = 0
            }
        }

        private func process(faceAnchor: ARFaceAnchor) {
            guard faceAnchor.isTracked else {
                markFaceLost(force: false)
                return
            }

            faceRemovalWorkItem?.cancel()
            lostFrameStreak = 0
            faceDetected = true
            trackedFrameCount += 1
            stableFrameCount += 1

            let z = faceAnchor.transform.columns.3.z
            let fillRatio = projectedFaceFillRatio(faceAnchor: faceAnchor)
            let distanceFeedback = FaceScanQualityValidator.distanceFeedback(
                z: z,
                screenFillRatio: fillRatio
            )

            if distanceFeedback != .ok, scanStartTime == nil {
                distanceOkFrameCount = 0
                publishUI(force: false) {
                    self.isFaceDetected = self.trackedFrameCount >= 4
                    self.instruction = FaceScanQualityValidator.distanceInstruction(for: distanceFeedback)
                    self.frameHint = FaceScanQualityValidator.distanceHint(for: distanceFeedback)
                }
                return
            }

            distanceOkFrameCount += 1

            if scanStartTime == nil {
                guard trackedFrameCount >= minTrackedFramesBeforeScan else {
                    publishUI(force: false) {
                        self.isFaceDetected = false
                        self.instruction = "Place ton visage dans le cadre."
                        self.frameHint = "Rapproche-toi pour bien remplir le cadre."
                    }
                    return
                }

                guard distanceOkFrameCount >= minDistanceOkFramesBeforeScan else {
                    publishUI(force: false) {
                        self.isFaceDetected = true
                        self.instruction = FaceScanQualityValidator.distanceInstruction(for: .ok)
                        self.frameHint = "Ne bouge plus — le scan va démarrer."
                    }
                    return
                }

                beginScan(with: faceAnchor)
                return
            }

            guard referenceTransform != nil else { return }

            registerHeadPose(from: faceAnchor.transform)
            accumulateBlendShapes(faceAnchor.blendShapes)

            guard let scanStart = scanStartTime else { return }
            let elapsed = Date().timeIntervalSince(scanStart)
            let tickProgress = Double(filledTickSectors.count) / Double(tickCount)
            let combinedProgress = progressValue(elapsed: elapsed, tickProgress: tickProgress)

            if elapsed > 0.35, sampledMeshes.count < 60 {
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
            publishUI(
                ring: combinedProgress,
                progress: combinedProgress,
                force: sectorsChanged || Int(elapsed * 10) % 3 == 0
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

            guard !scanExhausted else { return }

            let bestMesh = resolveBestMesh()
            if qualityReady(elapsed: elapsed, tickProgress: tickProgress),
               FaceScanQualityValidator.meshIsSolid(bestMesh) {
                finishScan(bestMesh: bestMesh)
            } else if elapsed >= scanDuration * 1.25 {
                handleQualityFailure()
            }
        }

        private func progressValue(elapsed: TimeInterval, tickProgress: Double? = nil) -> Double {
            let tick = tickProgress ?? Double(filledTickSectors.count) / Double(tickCount)
            let time = min(1, elapsed / scanDuration)
            // La progression visuelle suit surtout les angles visités, pas le temps seul.
            return min(1, tick * 0.92 + time * 0.08)
        }

        private func qualityReady(elapsed: TimeInterval, tickProgress: Double) -> Bool {
            guard elapsed >= scanDuration * 0.72 else { return false }
            guard tickProgress >= minTickProgress else { return false }
            guard filledTickSectors.count >= minSectorsToComplete else { return false }
            guard FaceScanQualityValidator.headSpreadIsSufficient(angleSamples) else { return false }

            let flashActive = FaceScanScreenFlash.shared.isActive
            let snap = bestSnapshot ?? arView?.snapshot()
            let minLuma: CGFloat = flashActive ? 0.08 : (isLowLight ? 0.14 : 0.10)
            return FaceScanQualityValidator.snapshotIsUsable(
                snap,
                minimumLuminance: minLuma,
                screenFlashActive: flashActive
            )
        }

        private func qualityHint(elapsed: TimeInterval, tickProgress: Double) -> String {
            if tickProgress < minTickProgress {
                return "Tourne plus la tête pour remplir le cercle."
            }
            if !FaceScanQualityValidator.headSpreadIsSufficient(angleSamples) {
                return "Fais de plus grands mouvements de tête."
            }
            let flashActive = FaceScanScreenFlash.shared.isActive
            let snap = bestSnapshot ?? arView?.snapshot()
            if !FaceScanQualityValidator.snapshotIsUsable(
                snap,
                minimumLuminance: flashActive ? 0.08 : (isLowLight ? 0.14 : 0.10),
                screenFlashActive: flashActive
            ) {
                return flashActive
                    ? "Garde le visage centré face à l'écran."
                    : (isLowLight ? "Active le flash ou rapproche-toi." : "Cherche plus de lumière.")
            }
            if elapsed < scanDuration * 0.72 {
                return "Encore quelques secondes…"
            }
            return "Finalisation…"
        }

        private func handleQualityFailure() {
            let now = Date()
            if let last = lastQualityFailureAt, now.timeIntervalSince(last) < 1.8 { return }
            lastQualityFailureAt = now

            qualityRetryCount += 1
            if qualityRetryCount >= 4 {
                if !scanExhausted {
                    scanExhausted = true
                    publishUI(force: true) {
                        self.instruction = "Scan difficile — active le flash et réessaie."
                        self.frameHint = "Rapproche-toi puis replace ton visage dans le cadre."
                    }
                    HapticManager.shared.notification(.warning)
                }
                return
            }

            resetScanTracking(soft: false)
            publishUI(force: true) {
                self.progress = 0
                self.ringProgress = 0
                self.activeTickSectors = []
                self.instruction = "On recommence — tourne la tête plus lentement."
                self.frameHint = self.isLowLight ? "Environnement sombre" : nil
                HapticManager.shared.notification(.warning)
            }
        }

        private func resolveBestMesh() -> FaceMesh3DData {
            sampledMeshes
                .filter { FaceScanQualityValidator.meshIsSolid($0) }
                .max(by: { $0.vertices.count < $1.vertices.count })
                ?? sampledMeshes.max(by: { $0.vertices.count < $1.vertices.count })
                ?? .empty
        }

        private func finishScan(bestMesh: FaceMesh3DData) {
            let mesh = resolveBestMesh()
            guard FaceScanQualityValidator.meshIsSolid(mesh) else {
                handleQualityFailure()
                return
            }

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
                    mesh: mesh,
                    snapshot: snapshot,
                    videoFilename: videoFilename,
                    averageBlendShapes: shapes,
                    yawCoverage: Double(filledTickSectors.count) / Double(tickCount)
                )

                await MainActor.run {
                    guard !self.isTornDown else { return }
                    self.publishUI(force: true) {
                        self.progress = 1
                        self.ringProgress = 1
                        self.activeTickSectors = self.filledTickSectors
                        self.instruction = "Analyse terminée."
                        self.frameHint = nil
                        HapticManager.shared.notification(.success)
                        self.onComplete(payload)
                    }
                }
            }
        }

        // MARK: - Pose → anneau Face ID (direction réelle sur l'écran)

        /// Pitch (haut/bas) et yaw (gauche/droite) — utilisé pour la qualité du scan.
        private func relativeYawPitch(from transform: simd_float4x4) -> SIMD2<Float> {
            guard let ref = referenceTransform else { return .zero }
            let rel = simd_mul(simd_inverse(ref), transform)
            let forward = rel.columns.2
            let pitch = asin(max(-1, min(1, -forward.y)))
            let yaw = atan2(forward.x, forward.z)
            return SIMD2(pitch, yaw)
        }

        /// Secteur sur l'anneau : 0 = haut, sens horaire (aligné sur `FaceIDTickProgressRing`).
        private func sectorIndex(for transform: simd_float4x4) -> Int? {
            guard let ref = referenceTransform else { return nil }
            let rel = simd_mul(simd_inverse(ref), transform)
            let forward = rel.columns.2

            // Projection du nez sur le plan écran : haut = +vertical, droite = +horizontal.
            let horizontal = forward.x
            let vertical = -forward.y
            let planar = sqrt(horizontal * horizontal + vertical * vertical)
            guard planar >= sin(minActivationAngle) else { return nil }

            // atan2(horizontal, vertical) : 0 = haut, π/2 = droite, π = bas, 3π/2 = gauche.
            var compass = atan2(horizontal, vertical)
            if compass < 0 { compass += 2 * Float.pi }
            return Int(compass / (2 * Float.pi) * Float(tickCount)) % tickCount
        }

        /// Enregistre le secteur visité selon l'inclinaison réelle (comme Face ID).
        private func registerHeadPose(from transform: simd_float4x4) {
            let angles = relativeYawPitch(from: transform)
            angleSamples.append(angles)
            if angleSamples.count > 200 {
                angleSamples.removeFirst(angleSamples.count - 200)
            }

            guard let sector = sectorIndex(for: transform) else { return }

            filledTickSectors.insert(sector)

            if let last = lastRegisteredSector, last != sector {
                let forward = (sector - last + tickCount) % tickCount
                let backward = (last - sector + tickCount) % tickCount
                let gap = min(forward, backward)

                // Combler uniquement les petits écarts (mouvement fluide), jamais un demi-cercle d'un coup.
                if gap <= maxSectorBridgeSteps + 1 {
                    let steps = min(gap - 1, maxSectorBridgeSteps)
                    if steps > 0 {
                        if forward <= backward {
                            for step in 1...steps {
                                filledTickSectors.insert((last + step) % tickCount)
                            }
                        } else {
                            for step in 1...steps {
                                filledTickSectors.insert((last - step + tickCount) % tickCount)
                            }
                        }
                    }
                }
            }
            lastRegisteredSector = sector
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

        private func projectedFaceFillRatio(faceAnchor: ARFaceAnchor) -> CGFloat? {
            guard let view = arView else { return nil }
            let bounds = view.bounds
            guard bounds.width > 1, bounds.height > 1 else { return nil }

            let transform = faceAnchor.transform
            var minX = CGFloat.infinity
            var maxX = -CGFloat.infinity
            var minY = CGFloat.infinity
            var maxY = -CGFloat.infinity
            var projectedCount = 0

            let vertices = faceAnchor.geometry.vertices
            for (index, vertex) in vertices.enumerated() where index.isMultiple(of: 4) {
                let local = transform * SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1)
                let projected = view.projectPoint(SCNVector3(local.x, local.y, local.z))
                guard projected.z > 0, projected.z < 1 else { continue }

                let point = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
                projectedCount += 1
            }

            guard projectedCount >= 10 else { return nil }
            let faceArea = (maxX - minX) * (maxY - minY)
            guard faceArea > 1 else { return nil }
            return faceArea / (bounds.width * bounds.height)
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
