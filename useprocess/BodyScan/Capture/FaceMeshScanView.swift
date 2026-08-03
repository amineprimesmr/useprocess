import ARKit
import SceneKit
import SwiftUI
import UIKit

private final class FaceMeshSceneView: ARSCNView {
    var onViewportSizeChange: ((CGSize) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onViewportSizeChange?(bounds.size)
    }
}

/// Scan visage — mesh 3D invisible, flash piloté par l'écran parent.
struct FaceMeshScanView: UIViewRepresentable {
    @Binding var progress: Double
    @Binding var ringProgress: Double
    @Binding var activeTickSectors: Set<Int>
    @Binding var overlayMode: FaceScanCaptureOverlayMode
    @Binding var tiltHoldProgress: Double
    @Binding var tiltDirection: FaceScanTiltDirection
    @Binding var tiltIsEngaged: Bool
    @Binding var instruction: String
    @Binding var frameHint: String?
    @Binding var isFaceDetected: Bool
    @Binding var isDeviceSupported: Bool
    @Binding var isLowLight: Bool
    var isPreviewOnly: Bool = false
    var isSessionRunning: Bool = true
    var allowsScreenFlash: Bool = true
    var cameraZoom: CGFloat = 1
    var onComplete: (FaceScanCapturePayload) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            progress: $progress,
            ringProgress: $ringProgress,
            activeTickSectors: $activeTickSectors,
            overlayMode: $overlayMode,
            tiltHoldProgress: $tiltHoldProgress,
            tiltDirection: $tiltDirection,
            tiltIsEngaged: $tiltIsEngaged,
            instruction: $instruction,
            frameHint: $frameHint,
            isFaceDetected: $isFaceDetected,
            isDeviceSupported: $isDeviceSupported,
            isLowLight: $isLowLight,
            allowsScreenFlash: allowsScreenFlash,
            cameraZoom: cameraZoom,
            onComplete: onComplete
        )
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = FaceMeshSceneView(frame: .zero)
        view.delegate = context.coordinator
        view.session.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        view.scene = SCNScene()
        view.backgroundColor = .black
        view.rendersCameraGrain = false
        view.preferredFramesPerSecond = 30
        context.coordinator.arView = view
        view.onViewportSizeChange = { [weak coordinator = context.coordinator] size in
            coordinator?.updateViewportSize(size)
        }

        guard ARFaceTrackingConfiguration.isSupported else {
            DispatchQueue.main.async {
                context.coordinator.isDeviceSupported = false
                instruction = "Caméra avant requise — utilise un iPhone avec Face ID."
                frameHint = nil
                isFaceDetected = false
                progress = 0
                ringProgress = 0
                activeTickSectors = []
                overlayMode = .orbitTicks
                tiltHoldProgress = 0
                tiltDirection = .none
                tiltIsEngaged = false
            }
            return view
        }

        DispatchQueue.main.async {
            context.coordinator.isDeviceSupported = true
        }

        context.coordinator.isSessionRunning = isSessionRunning
        if isSessionRunning {
            context.coordinator.startSession(on: view)
        } else {
            context.coordinator.isSessionPaused = true
        }
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        let wasPreview = context.coordinator.isPreviewOnly
        context.coordinator.isPreviewOnly = isPreviewOnly
        context.coordinator.allowsScreenFlash = allowsScreenFlash
        context.coordinator.cameraZoom = cameraZoom
        context.coordinator.onComplete = onComplete
        context.coordinator.updateViewportSize(uiView.bounds.size)

        if isSessionRunning != context.coordinator.isSessionRunning {
            context.coordinator.isSessionRunning = isSessionRunning
            if isSessionRunning {
                context.coordinator.resumeSessionIfPaused()
            } else {
                context.coordinator.pauseSession()
            }
        }

        if isPreviewOnly, !wasPreview {
            context.coordinator.enterPreviewMode()
        } else if !isPreviewOnly, wasPreview {
            context.coordinator.exitPreviewMode()
        }
    }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        coordinator.tearDown()
        uiView.session.pause()
        (uiView as? FaceMeshSceneView)?.onViewportSizeChange = nil
        coordinator.arView = nil
        coordinator.faceNode = nil
    }

    final class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        @Binding var progress: Double
        @Binding var ringProgress: Double
        @Binding var activeTickSectors: Set<Int>
        @Binding var overlayMode: FaceScanCaptureOverlayMode
        @Binding var tiltHoldProgress: Double
        @Binding var tiltDirection: FaceScanTiltDirection
        @Binding var tiltIsEngaged: Bool
        @Binding var instruction: String
        @Binding var frameHint: String?
        @Binding var isFaceDetected: Bool
        @Binding var isDeviceSupported: Bool
        @Binding var isLowLight: Bool
        var allowsScreenFlash: Bool
        var cameraZoom: CGFloat
        var onComplete: (FaceScanCapturePayload) -> Void

        weak var arView: ARSCNView?
        weak var faceNode: SCNNode?

        let scanDuration: TimeInterval = 5.5
        let tickCount = 72
        let minSectorsToComplete = 48
        let minTickProgress = 0.65
        let maxHeadRotation: Float = 0.55
        let minTrackedFramesBeforeScan = 6
        let minDistanceOkFramesBeforeScan = 8
        let minActivationAngle: Float = 0.06
        let maxSectorBridgeSteps = 1
        let lostFrameThresholdPositioning = 30
        let lostFrameThresholdScanning = 55
        /// Penché latéral (oreille → épaule) pour faire migrer le liquide sous gravité.
        let minTiltRoll: Float = 0.28
        let tiltHoldFramesRequired = 16
        let maxGazeAngleDuringTilt: Float = 0.42
        let tiltPhaseTimeout: TimeInterval = 14

        private enum LiveScanPhase {
            case orbit
            case fluidTiltLeft
            case fluidTiltRight
        }

        var completed = false
        var didDeliverCapture = false
        var isTornDown = false
        var isPreviewOnly = false
        var isSessionRunning = true
        var isSessionPaused = false
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
        private var livePhase: LiveScanPhase = .orbit
        private var tiltPhaseStartedAt: Date?
        private var tiltHoldFrames = 0
        private var leftTiltMesh: FaceMesh3DData?
        private var rightTiltMesh: FaceMesh3DData?
        private var peakLeftRoll: Float = 0
        private var peakRightRoll: Float = 0
        /// Signe du roll pour le 1er penché (+1 / -1). Le 2e exige l’opposé.
        private var firstTiltSign: Float = 0

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
        private var lastMediaSampleTime: CFTimeInterval = 0
        private var lastQualityFailureAt: Date?
        private let uiUpdateMinInterval: CFTimeInterval = 1.0 / 20.0
        private let lightUIUpdateMinInterval: CFTimeInterval = 1.0 / 15.0
        private let processMinInterval: CFTimeInterval = 1.0 / 24.0
        private var didConfigurePortraitCamera = false
        private var faceRemovalWorkItem: DispatchWorkItem?
        private let viewportLock = NSLock()
        private var viewportSize: CGSize = .zero

        init(
            progress: Binding<Double>,
            ringProgress: Binding<Double>,
            activeTickSectors: Binding<Set<Int>>,
            overlayMode: Binding<FaceScanCaptureOverlayMode>,
            tiltHoldProgress: Binding<Double>,
            tiltDirection: Binding<FaceScanTiltDirection>,
            tiltIsEngaged: Binding<Bool>,
            instruction: Binding<String>,
            frameHint: Binding<String?>,
            isFaceDetected: Binding<Bool>,
            isDeviceSupported: Binding<Bool>,
            isLowLight: Binding<Bool>,
            allowsScreenFlash: Bool,
            cameraZoom: CGFloat,
            onComplete: @escaping (FaceScanCapturePayload) -> Void
        ) {
            _progress = progress
            _ringProgress = ringProgress
            _activeTickSectors = activeTickSectors
            _overlayMode = overlayMode
            _tiltHoldProgress = tiltHoldProgress
            _tiltDirection = tiltDirection
            _tiltIsEngaged = tiltIsEngaged
            _instruction = instruction
            _frameHint = frameHint
            _isFaceDetected = isFaceDetected
            _isDeviceSupported = isDeviceSupported
            _isLowLight = isLowLight
            self.allowsScreenFlash = allowsScreenFlash
            self.cameraZoom = cameraZoom
            self.onComplete = onComplete
        }

        func tearDown() {
            isTornDown = true
            faceRemovalWorkItem?.cancel()
            videoRecorder.cancel()
        }

        func enterPreviewMode() {
            guard !isTornDown else { return }
            completed = false
            didDeliverCapture = false
            scanExhausted = false
            resetScanTracking(soft: false)
            publishUI(force: true) {
                self.instruction = ""
                self.frameHint = nil
                self.progress = 0
                self.ringProgress = 0
                self.activeTickSectors = []
                self.overlayMode = .orbitTicks
                self.tiltHoldProgress = 0
                self.tiltDirection = .none
                self.tiltIsEngaged = false
            }
        }

        /// Passe en mode scan actif sans interrompre la session AR (expansion inline accueil).
        func exitPreviewMode() {
            guard !isTornDown else { return }
            isPreviewOnly = false
            completed = false
            didDeliverCapture = false
            scanExhausted = false
            resetScanTracking(soft: false)
            publishUI(force: true) {
                self.isFaceDetected = self.trackedFrameCount >= 4
                self.instruction = "Rapproche-toi pour que ton visage remplisse le cadre."
                self.frameHint = nil
                self.progress = 0
                self.ringProgress = 0
                self.activeTickSectors = []
                self.overlayMode = .orbitTicks
                self.tiltHoldProgress = 0
                self.tiltDirection = .none
                self.tiltIsEngaged = false
            }
        }

        func updateViewportSize(_ size: CGSize) {
            viewportLock.lock()
            viewportSize = size
            viewportLock.unlock()
        }

        private func currentViewportSize() -> CGSize {
            viewportLock.lock()
            defer { viewportLock.unlock() }
            return viewportSize
        }

        func startSession(on view: ARSCNView) {
            ProcessAudioSession.configureForMixingWithOthers()
            let config = ARFaceTrackingConfiguration()
            config.isLightEstimationEnabled = true
            config.maximumNumberOfTrackedFaces = 1
            view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            isSessionPaused = false
        }

        func pauseSession() {
            guard !isSessionPaused, let view = arView else { return }
            view.session.pause()
            isSessionPaused = true
        }

        func resumeSessionIfPaused() {
            guard isSessionPaused, !isTornDown, let view = arView else { return }
            startSession(on: view)
        }

        func recoverSessionIfNeeded() {
            guard isSessionRunning, !isSessionPaused else { return }
            guard !isTornDown, !completed, let view = arView else { return }
            guard sessionRecoveryAttempts < 2 else { return }
            sessionRecoveryAttempts += 1
            startSession(on: view)
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard !completed, !isTornDown else { return }
            let intensity = frame.lightEstimate?.ambientIntensity ?? 1000
            currentAmbientIntensity = intensity
            let low = FaceScanQualityValidator.isLowLight(ambientIntensity: intensity)

            if scanStartTime != nil {
                videoRecorder.append(
                    pixelBuffer: frame.capturedImage,
                    timestamp: frame.timestamp
                )
            }

            let now = CACurrentMediaTime()
            guard now - lastLightUIUpdate >= lightUIUpdateMinInterval else { return }
            lastLightUIUpdate = now

            DispatchQueue.main.async {
                if FaceScanScreenFlash.shared.isActive {
                    if !self.isLowLight { self.isLowLight = true }
                } else {
                    let wasLow = self.isLowLight
                    self.isLowLight = low
                    if !self.allowsScreenFlash, !self.isPreviewOnly {
                        if low {
                            self.enforceInsufficientLightLock()
                        } else if wasLow {
                            self.clearInsufficientLightLock()
                        }
                    }
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
            configurePortraitCameraIfNeeded()

            let now = CACurrentMediaTime()
            guard now - lastProcessTime >= processMinInterval else { return }
            lastProcessTime = now
            process(faceAnchor: faceAnchor, renderer: renderer)
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
            if isPreviewOnly {
                publishUI(force: true) {
                    self.isFaceDetected = false
                    self.progress = 0
                    self.ringProgress = 0
                    self.activeTickSectors = []
                    self.resetOverlayToOrbit()
                    self.instruction = ""
                    self.frameHint = nil
                }
                return
            }
            publishUI(force: true) {
                self.isFaceDetected = false
                self.progress = 0
                self.ringProgress = 0
                self.activeTickSectors = []
                self.resetOverlayToOrbit()
                if !self.allowsScreenFlash && self.isLowLight {
                    self.instruction = "Pas assez de lumière pour lancer le scan."
                    self.frameHint = "Place-toi face à une fenêtre ou une lampe."
                } else {
                    self.instruction = "Place ton visage dans le cadre."
                    self.frameHint = nil
                }
            }
        }

        private func enforceInsufficientLightLock(faceVisible: Bool = false) {
            guard !completed, !isTornDown, !isPreviewOnly else { return }
            if scanStartTime != nil {
                resetScanTracking(soft: false)
            }
            publishUI(ring: 0, progress: 0, force: true) {
                if faceVisible {
                    self.isFaceDetected = true
                }
                self.instruction = "Pas assez de lumière pour lancer le scan."
                self.frameHint = "Place-toi face à une fenêtre ou une lampe."
                self.activeTickSectors = []
                self.resetOverlayToOrbit()
            }
        }

        private func clearInsufficientLightLock() {
            guard !completed, !isTornDown, !isPreviewOnly, scanStartTime == nil else { return }
            publishUI(force: true) {
                self.instruction = "Rapproche-toi pour que ton visage remplisse le cadre."
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
                completed = false
                didDeliverCapture = false
                filledTickSectors.removeAll()
                angleSamples.removeAll()
                sampledMeshes.removeAll()
                blendShapeAccumulators.removeAll()
                bestSnapshot = nil
                lastMediaSampleTime = 0
                videoRecorder.cancel()
                activeScanId = UUID().uuidString
                livePhase = .orbit
                tiltPhaseStartedAt = nil
                tiltHoldFrames = 0
                leftTiltMesh = nil
                rightTiltMesh = nil
                peakLeftRoll = 0
                peakRightRoll = 0
                firstTiltSign = 0
            }
        }

        private func beginScan(with faceAnchor: ARFaceAnchor) {
            guard scanStartTime == nil, !isPreviewOnly else { return }
            guard !( !allowsScreenFlash && isLowLight ) else {
                enforceInsufficientLightLock()
                return
            }

            activeScanId = UUID().uuidString
            videoRecorder.start(at: videoRecorder.prepareOutputURL(scanId: activeScanId))
            scanStartTime = Date()
            referenceTransform = faceAnchor.transform
            filledTickSectors.removeAll()
            lastRegisteredSector = nil
            livePhase = .orbit
            tiltPhaseStartedAt = nil
            tiltHoldFrames = 0
            leftTiltMesh = nil
            rightTiltMesh = nil
            peakLeftRoll = 0
            peakRightRoll = 0
            firstTiltSign = 0
            angleSamples.append(relativeYawPitch(from: faceAnchor.transform))

            publishUI(ring: 0, progress: 0.02, force: true) {
                HapticManager.shared.impact(.soft)
                self.isFaceDetected = true
                self.instruction = "Tourne lentement la tête pour compléter le cercle."
                self.frameHint = nil
                self.activeTickSectors = []
                self.ringProgress = 0
                self.overlayMode = .orbitTicks
                self.tiltHoldProgress = 0
                self.tiltDirection = .none
                self.tiltIsEngaged = false
            }
        }

        private func process(faceAnchor: ARFaceAnchor, renderer: SCNSceneRenderer) {
            guard faceAnchor.isTracked else {
                markFaceLost(force: false)
                return
            }

            if !allowsScreenFlash && isLowLight && !isPreviewOnly {
                enforceInsufficientLightLock(faceVisible: true)
                return
            }

            faceRemovalWorkItem?.cancel()
            lostFrameStreak = 0
            faceDetected = true
            trackedFrameCount += 1
            stableFrameCount += 1

            if isPreviewOnly {
                publishUI(force: false) {
                    self.isFaceDetected = self.trackedFrameCount >= 4
                    self.instruction = ""
                    self.frameHint = nil
                }
                return
            }

            let distanceMeters = faceDistanceFromCamera(faceAnchor: faceAnchor)
            let fillRatio = projectedFaceFillRatio(
                faceAnchor: faceAnchor,
                renderer: renderer
            )
            let distanceFeedback = FaceScanQualityValidator.distanceFeedback(
                distanceMeters: distanceMeters,
                screenFillRatio: fillRatio,
                cameraZoom: cameraZoom
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
                        self.frameHint = "Ne bouge plus. Le scan va démarrer."
                    }
                    return
                }

                beginScan(with: faceAnchor)
                return
            }

            guard referenceTransform != nil else { return }

            switch livePhase {
            case .orbit:
                processOrbitPhase(faceAnchor: faceAnchor)
            case .fluidTiltLeft, .fluidTiltRight:
                processFluidTiltPhase(faceAnchor: faceAnchor)
            }
        }

        private func processOrbitPhase(faceAnchor: ARFaceAnchor) {
            registerHeadPose(from: faceAnchor.transform)
            accumulateBlendShapes(faceAnchor.blendShapes)

            guard let scanStart = scanStartTime else { return }
            let elapsed = Date().timeIntervalSince(scanStart)
            let tickProgress = Double(filledTickSectors.count) / Double(tickCount)
            let combinedProgress = progressValue(elapsed: elapsed, tickProgress: tickProgress) * 0.78

            sampleMediaIfNeeded(elapsed: elapsed, faceAnchor: faceAnchor)

            let instructionText: String
            if tickProgress < 0.35 {
                instructionText = "Tourne lentement la tête. Gauche, droite, haut, bas."
            } else if tickProgress < minTickProgress {
                instructionText = "Continue à tourner la tête pour compléter le cercle."
            } else if !orbitQualityReady(elapsed: elapsed, tickProgress: tickProgress) {
                instructionText = qualityHint(elapsed: elapsed, tickProgress: tickProgress)
            } else {
                instructionText = "Parfait. Passe au test de rétention."
            }

            let sectorSignature = filledTickSectors.reduce(0) { $0 ^ ($1 &* 31) }
            let sectorsChanged = sectorSignature != lastPublishedSectorSignature
            publishUI(
                ring: min(1, Double(filledTickSectors.count) / Double(tickCount)),
                progress: combinedProgress,
                force: sectorsChanged || Int(elapsed * 10) % 3 == 0
            ) {
                self.isFaceDetected = true
                self.frameHint = nil
                self.overlayMode = .orbitTicks
                self.tiltHoldProgress = 0
                self.tiltDirection = .none
                self.tiltIsEngaged = false
                self.activeTickSectors = self.filledTickSectors
                self.instruction = instructionText
                if sectorsChanged {
                    HapticManager.shared.selection()
                    self.lastPublishedSectorSignature = sectorSignature
                }
            }

            guard !scanExhausted else { return }

            let bestMesh = resolveBestMesh()
            if orbitQualityReady(elapsed: elapsed, tickProgress: tickProgress),
               FaceScanQualityValidator.meshIsSolid(bestMesh) {
                enterFluidTiltPhase()
            } else if elapsed >= scanDuration * 1.25 {
                handleQualityFailure()
            }
        }

        private func enterFluidTiltPhase() {
            livePhase = .fluidTiltLeft
            tiltPhaseStartedAt = Date()
            tiltHoldFrames = 0
            peakLeftRoll = 0
            peakRightRoll = 0
            firstTiltSign = 0
            leftTiltMesh = nil
            rightTiltMesh = nil
            publishUI(ring: 0, progress: 0.78, force: true) {
                HapticManager.shared.impact(.medium)
                self.isFaceDetected = true
                self.overlayMode = .tiltHold
                self.activeTickSectors = []
                self.tiltHoldProgress = 0
                // Gauche d’abord, puis droite — jamais les deux en même temps.
                self.tiltDirection = .left
                self.tiltIsEngaged = false
                self.instruction = "Regarde la caméra. Penche la tête à gauche."
                self.frameHint = "Oreille gauche vers l’épaule, sans tourner le visage."
            }
        }

        private func processFluidTiltPhase(faceAnchor: ARFaceAnchor) {
            accumulateBlendShapes(faceAnchor.blendShapes)

            let pose = relativeYawPitchRoll(from: faceAnchor.transform)
            let pitch = pose.x
            let yaw = pose.y
            let roll = pose.z
            let lookingAtCamera = abs(yaw) <= maxGazeAngleDuringTilt && abs(pitch) <= maxGazeAngleDuringTilt
            let rollMagnitude = abs(roll)
            let isFirstSide = livePhase == .fluidTiltLeft

            // Convention ARKit : roll < 0 ≈ penché à gauche, roll > 0 ≈ à droite.
            let correctSide: Bool
            let wrongSide: Bool
            if isFirstSide {
                correctSide = roll <= -minTiltRoll
                wrongSide = roll >= minTiltRoll
            } else {
                correctSide = roll >= minTiltRoll
                wrongSide = roll <= -minTiltRoll
            }

            if lookingAtCamera && correctSide {
                tiltHoldFrames += 1
                let mesh = extractMesh(from: faceAnchor.geometry)
                if isFirstSide {
                    firstTiltSign = -1
                    if rollMagnitude > abs(peakLeftRoll) {
                        peakLeftRoll = roll
                        leftTiltMesh = mesh
                        if sampledMeshes.count < 28 { sampledMeshes.append(mesh) }
                        if let snap = arView?.snapshot() { bestSnapshot = snap }
                    }
                } else if rollMagnitude > abs(peakRightRoll) {
                    peakRightRoll = roll
                    rightTiltMesh = mesh
                    if sampledMeshes.count < 28 { sampledMeshes.append(mesh) }
                    if let snap = arView?.snapshot() { bestSnapshot = snap }
                }
            } else if lookingAtCamera && wrongSide {
                tiltHoldFrames = max(0, tiltHoldFrames - 2)
            } else {
                tiltHoldFrames = max(0, tiltHoldFrames - 1)
            }

            let holdRatio = min(1, Double(tiltHoldFrames) / Double(tiltHoldFramesRequired))
            let baseProgress = isFirstSide ? 0.78 : 0.89
            let progress = baseProgress + holdRatio * 0.11

            let instructionText: String
            let hintText: String?
            if !lookingAtCamera {
                instructionText = "Garde les yeux vers la caméra."
                hintText = "Penche seulement la tête, sans tourner le visage."
            } else if wrongSide {
                instructionText = isFirstSide
                    ? "Penche à gauche, pas à droite."
                    : "Penche à droite maintenant."
                hintText = "Oreille vers l’épaule, regard fixe."
            } else if !correctSide {
                instructionText = isFirstSide
                    ? "Regarde la caméra. Penche la tête à gauche."
                    : "Regarde la caméra. Penche la tête à droite."
                hintText = "Un peu plus fort, puis tiens la pose."
            } else if holdRatio < 1 {
                instructionText = "Tiens cette position…"
                hintText = nil
            } else {
                instructionText = isFirstSide
                    ? "Parfait. Maintenant à droite."
                    : "Finalisation du scan…"
                hintText = nil
            }

            let engaged = lookingAtCamera && correctSide
            let direction = tiltDirectionForPhase(isFirstSide: isFirstSide)

            publishUI(ring: holdRatio, progress: progress, force: true) {
                self.isFaceDetected = true
                self.overlayMode = .tiltHold
                self.activeTickSectors = []
                self.tiltHoldProgress = holdRatio
                self.tiltDirection = direction
                self.tiltIsEngaged = engaged
                self.instruction = instructionText
                self.frameHint = hintText
            }

            if !isFirstSide && holdRatio >= 1 {
                let bestMesh = resolveBestMesh()
                if FaceScanQualityValidator.meshIsSolid(bestMesh) {
                    finishScan()
                } else {
                    handleQualityFailure()
                }
                return
            }

            if tiltHoldFrames >= tiltHoldFramesRequired {
                if isFirstSide {
                    livePhase = .fluidTiltRight
                    tiltHoldFrames = 0
                    publishUI(ring: 0, progress: 0.89, force: true) {
                        HapticManager.shared.impact(.medium)
                        self.overlayMode = .tiltHold
                        self.activeTickSectors = []
                        self.tiltHoldProgress = 0
                        self.tiltDirection = .right
                        self.tiltIsEngaged = false
                        self.instruction = "Regarde la caméra. Penche la tête à droite."
                        self.frameHint = "Oreille droite vers l’épaule, sans tourner le visage."
                    }
                    return
                }

                let bestMesh = resolveBestMesh()
                if FaceScanQualityValidator.meshIsSolid(bestMesh) {
                    finishScan()
                } else {
                    handleQualityFailure()
                }
                return
            }

            if let started = tiltPhaseStartedAt,
               Date().timeIntervalSince(started) >= tiltPhaseTimeout {
                let bestMesh = resolveBestMesh()
                if FaceScanQualityValidator.meshIsSolid(bestMesh) {
                    finishScan()
                } else {
                    handleQualityFailure()
                }
            }
        }

        private func sampleMediaIfNeeded(elapsed: TimeInterval, faceAnchor: ARFaceAnchor) {
            let mediaSampleTime = CACurrentMediaTime()
            if elapsed > 0.35,
               mediaSampleTime - lastMediaSampleTime >= 0.25,
               sampledMeshes.count < 24 {
                lastMediaSampleTime = mediaSampleTime
                sampledMeshes.append(extractMesh(from: faceAnchor.geometry))
                if let snap = arView?.snapshot() {
                    if bestSnapshot.map({
                        FaceScanQualityValidator.averageLuminance(of: snap)
                            > FaceScanQualityValidator.averageLuminance(of: $0)
                    }) ?? true {
                        bestSnapshot = snap
                    }
                }
            }
        }

        private func progressValue(elapsed: TimeInterval, tickProgress: Double? = nil) -> Double {
            let tick = tickProgress ?? Double(filledTickSectors.count) / Double(tickCount)
            let time = min(1, elapsed / scanDuration)
            return min(1, tick * 0.92 + time * 0.08)
        }

        private func orbitQualityReady(elapsed: TimeInterval, tickProgress: Double) -> Bool {
            guard elapsed >= scanDuration * 0.90 else { return false }
            guard tickProgress >= minTickProgress else { return false }
            guard filledTickSectors.count >= minSectorsToComplete else { return false }
            guard FaceScanQualityValidator.headSpreadIsSufficient(angleSamples, minimum: 0.24) else { return false }

            let flashActive = FaceScanScreenFlash.shared.isActive
            let minLuma: CGFloat = flashActive ? 0.06 : (isLowLight ? 0.09 : 0.07)
            return FaceScanQualityValidator.snapshotIsUsable(
                bestSnapshot,
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
            if !FaceScanQualityValidator.snapshotIsUsable(
                bestSnapshot,
                minimumLuminance: flashActive ? 0.06 : (isLowLight ? 0.09 : 0.07),
                screenFlashActive: flashActive
            ) {
                return flashActive
                    ? "Garde le visage centré face à l'écran."
                    : (isLowLight
                        ? (allowsScreenFlash
                            ? "Active le flash ou rapproche-toi."
                            : "Pas assez de lumière. Rapproche-toi d'une source lumineuse.")
                        : "Cherche plus de lumière.")
            }
            if elapsed < scanDuration * 0.90 {
                return "Encore quelques secondes…"
            }
            return "Finalisation…"
        }

        private func tiltDirectionForPhase(isFirstSide: Bool) -> FaceScanTiltDirection {
            isFirstSide ? .left : .right
        }

        private func resetOverlayToOrbit() {
            overlayMode = .orbitTicks
            tiltHoldProgress = 0
            tiltDirection = .none
            tiltIsEngaged = false
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
                        self.instruction = self.allowsScreenFlash
                            ? "Scan difficile. Active le flash et réessaie."
                            : "Scan difficile. Cherche plus de lumière et réessaie."
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
                self.resetOverlayToOrbit()
                self.instruction = "On recommence. Tourne la tête plus lentement."
                self.frameHint = self.isLowLight
                    ? (self.allowsScreenFlash ? "Environnement sombre" : "Pas assez de lumière")
                    : nil
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

        private func finishScan() {
            guard !completed, !didDeliverCapture else { return }
            let mesh = resolveBestMesh()
            guard FaceScanQualityValidator.meshIsSolid(mesh) else {
                handleQualityFailure()
                return
            }

            completed = true
            didDeliverCapture = true
            pauseSession()

            let shapes = blendShapeAccumulators.mapValues { $0.sum / Float($0.count) }
            let scanId = activeScanId
            let snapshot = bestSnapshot
            let fluidShift = computeFluidShiftScore()
            let yawCoverage = Double(filledTickSectors.count) / Double(tickCount)
            let tickSectors = filledTickSectors

            Task { [weak self] in
                let videoURL = await self?.videoRecorder.finish()
                let videoFilename: String?
                if let videoURL, FileManager.default.fileExists(atPath: videoURL.path) {
                    videoFilename = FaceScanImageStore.videoFilename(for: scanId)
                } else {
                    videoFilename = nil
                }

                let payload = FaceScanCapturePayload(
                    scanId: scanId,
                    mesh: mesh,
                    snapshot: snapshot,
                    videoFilename: videoFilename,
                    averageBlendShapes: shapes,
                    yawCoverage: yawCoverage,
                    fluidShiftScore: fluidShift
                )

                await MainActor.run {
                    guard let self, !self.isTornDown else { return }
                    self.progress = 1
                    self.ringProgress = 1
                    self.activeTickSectors = tickSectors
                    self.overlayMode = .orbitTicks
                    self.tiltHoldProgress = 0
                    self.tiltDirection = .none
                    self.tiltIsEngaged = false
                    self.instruction = "Scan terminé."
                    self.frameHint = nil
                    HapticManager.shared.notification(.success)
                    self.onComplete(payload)
                }
            }
        }

        // MARK: - Pose → anneau Face ID (yaw/pitch) + roll (rétention)

        /// Distance 3D caméra ↔ visage (mètres). Le z brut du transform monde n'est pas fiable.
        private func faceDistanceFromCamera(faceAnchor: ARFaceAnchor) -> Float? {
            guard let frame = arView?.session.currentFrame else { return nil }
            let facePosition = faceAnchor.transform.columns.3
            let cameraPosition = frame.camera.transform.columns.3
            return simd_distance(
                SIMD3<Float>(facePosition.x, facePosition.y, facePosition.z),
                SIMD3<Float>(cameraPosition.x, cameraPosition.y, cameraPosition.z)
            )
        }

        /// Pitch (haut/bas), yaw (gauche/droite), roll (penché latéral) relatifs au départ du scan.
        private func relativeYawPitchRoll(from transform: simd_float4x4) -> SIMD3<Float> {
            guard let ref = referenceTransform else { return .zero }
            let rel = simd_mul(simd_inverse(ref), transform)
            let forward = rel.columns.2
            let up = rel.columns.1
            let pitch = asin(max(-1, min(1, -forward.y)))
            let yaw = atan2(forward.x, forward.z)
            let roll = atan2(up.x, up.y)
            return SIMD3(pitch, yaw, roll)
        }

        /// Pitch (haut/bas) et yaw (gauche/droite) par rapport à la pose de départ du scan.
        private func relativeYawPitch(from transform: simd_float4x4) -> SIMD2<Float> {
            let pose = relativeYawPitchRoll(from: transform)
            return SIMD2(pose.x, pose.y)
        }

        /// Asymétrie joue gauche/droite (z). Différence entre penché G et D = mobilité du liquide.
        private func computeFluidShiftScore() -> Double {
            guard let leftMesh = leftTiltMesh, let rightMesh = rightTiltMesh else {
                if leftTiltMesh != nil || rightTiltMesh != nil { return 0.06 }
                return 0
            }
            let leftAsym = cheekDepthAsymmetry(leftMesh)
            let rightAsym = cheekDepthAsymmetry(rightMesh)
            let mobility = abs(leftAsym - rightAsym)
            return min(1, Double(mobility) * 14)
        }

        private func cheekDepthAsymmetry(_ mesh: FaceMesh3DData) -> Float {
            let left = averageCheekZ(mesh, positiveX: false)
            let right = averageCheekZ(mesh, positiveX: true)
            guard let left, let right else { return 0 }
            return right - left
        }

        private func averageCheekZ(_ mesh: FaceMesh3DData, positiveX: Bool) -> Float? {
            let count = mesh.vertices.count / 3
            guard count > 20 else { return nil }
            var sum: Float = 0
            var n = 0
            for i in 0..<count {
                let x = mesh.vertices[i * 3]
                let y = mesh.vertices[i * 3 + 1]
                let z = mesh.vertices[i * 3 + 2]
                guard y > -0.05, y < 0.03 else { continue }
                if positiveX {
                    guard x > 0.045, x < 0.13 else { continue }
                } else {
                    guard x < -0.045, x > -0.13 else { continue }
                }
                sum += z
                n += 1
            }
            return n > 8 ? sum / Float(n) : nil
        }

                /// Décalage entre l'angle mathématique et `FaceIDTickProgressRing` (index 0 = gauche, 18 = haut).
        private var tickRingTopSectorOffset: Int { tickCount / 4 }

        /// Secteurs à allumer selon où l'utilisateur regarde (haut/bas/gauche/droite).
        private func visitedSectors(for transform: simd_float4x4) -> [Int] {
            guard referenceTransform != nil else { return [] }

            let angles = relativeYawPitch(from: transform)
            let pitch = angles.x
            let yaw = angles.y
            let magnitude = hypot(yaw, pitch)
            guard magnitude >= minActivationAngle else { return [] }

            // Boussole : 0 = haut, horaire (droite → bas → gauche).
            var compass = atan2(yaw, -pitch)
            if compass < 0 { compass += 2 * Float.pi }

            let rawSector = Int(compass / (2 * Float.pi) * Float(tickCount)) % tickCount
            let primary = (rawSector + tickRingTopSectorOffset) % tickCount

            // Plus l'inclinaison est marquée, plus on élargit l'arc vert autour de la direction.
            let spread = min(2, max(0, Int(magnitude / minActivationAngle) - 1))
            var sectors = [primary]
            if spread > 0 {
                for offset in 1...spread {
                    sectors.append((primary + offset) % tickCount)
                    sectors.append((primary - offset + tickCount) % tickCount)
                }
            }
            return sectors
        }

        /// Enregistre les secteurs visités selon l'inclinaison réelle de la tête.
        private func registerHeadPose(from transform: simd_float4x4) {
            let angles = relativeYawPitch(from: transform)
            angleSamples.append(angles)
            if angleSamples.count > 200 {
                angleSamples.removeFirst(angleSamples.count - 200)
            }

            let sectors = visitedSectors(for: transform)
            guard let sector = sectors.first else { return }

            for visited in sectors {
                filledTickSectors.insert(visited)
            }

            if let last = lastRegisteredSector, last != sector {
                let forward = (sector - last + tickCount) % tickCount
                let backward = (last - sector + tickCount) % tickCount
                let gap = min(forward, backward)

                // Combler uniquement les tout petits écarts (mouvement fluide), jamais un demi-cercle.
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
            guard !isTornDown, !completed else { return }
            let now = CACurrentMediaTime()
            if !force, now - lastUIUpdate < uiUpdateMinInterval { return }
            lastUIUpdate = now

            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isTornDown, !self.completed else { return }
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

        private func projectedFaceFillRatio(
            faceAnchor: ARFaceAnchor,
            renderer: SCNSceneRenderer
        ) -> CGFloat? {
            let viewport = currentViewportSize()
            guard viewport.width > 1, viewport.height > 1 else { return nil }

            let transform = faceAnchor.transform
            var minX = CGFloat.infinity
            var maxX = -CGFloat.infinity
            var minY = CGFloat.infinity
            var maxY = -CGFloat.infinity
            var projectedCount = 0

            let vertices = faceAnchor.geometry.vertices
            for (index, vertex) in vertices.enumerated() where index.isMultiple(of: 4) {
                let local = transform * SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1)
                let projected = renderer.projectPoint(SCNVector3(local.x, local.y, local.z))
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
            return faceArea / (viewport.width * viewport.height)
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
