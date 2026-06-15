import ARKit
import SceneKit
import SwiftUI

/// Scan visage style Face ID — mesh ARKit TrueDepth (vertices + indices + UV).
struct FaceMeshScanView: UIViewRepresentable {
    @Binding var progress: Double
    @Binding var instruction: String
    var onComplete: (FaceMesh3DData) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(progress: $progress, instruction: $instruction, onComplete: onComplete)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.delegate = context.coordinator
        view.session.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        view.scene = SCNScene()
        view.backgroundColor = .black
        context.coordinator.arView = view

        guard ARFaceTrackingConfiguration.isSupported else {
            DispatchQueue.main.async {
                instruction = "TrueDepth indisponible sur cet appareil"
                progress = 1
                onComplete(.empty)
            }
            return view
        }

        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.maximumNumberOfTrackedFaces = 1
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        context.coordinator.startTime = Date()
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
        coordinator.arView = nil
    }

    final class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        @Binding var progress: Double
        @Binding var instruction: String
        let onComplete: (FaceMesh3DData) -> Void

        weak var arView: ARSCNView?
        var startTime = Date()
        let scanDuration: TimeInterval = 8
        var completed = false
        var sampledMeshes: [FaceMesh3DData] = []
        var headAngles: Set<Int> = []
        var faceDetected = false

        init(
            progress: Binding<Double>,
            instruction: Binding<String>,
            onComplete: @escaping (FaceMesh3DData) -> Void
        ) {
            _progress = progress
            _instruction = instruction
            self.onComplete = onComplete
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            DispatchQueue.main.async {
                self.instruction = "Erreur ARKit — réessaie"
            }
        }

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let device = renderer.device else { return nil }
            let geometry = ARSCNFaceGeometry(device: device)!
            geometry.firstMaterial?.fillMode = .lines
            geometry.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.85)
            geometry.firstMaterial?.isDoubleSided = true
            return SCNNode(geometry: geometry)
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let geometry = node.geometry as? ARSCNFaceGeometry,
                  !completed else { return }

            geometry.update(from: faceAnchor.geometry)
            faceDetected = true

            let elapsed = Date().timeIntervalSince(startTime)
            progress = min(1, elapsed / scanDuration)

            let yaw = Int(faceAnchor.transform.columns.0.x * 50)
            let pitch = Int(faceAnchor.transform.columns.1.y * 50)
            let roll = Int(faceAnchor.transform.columns.2.z * 50)
            headAngles.insert(yaw * 10_000 + pitch * 100 + roll)

            updateInstruction(elapsed: elapsed)

            if elapsed > 0.4, sampledMeshes.count < 20 {
                sampledMeshes.append(extractMesh(from: faceAnchor.geometry))
            }

            if elapsed >= scanDuration, !completed {
                completed = true
                let best = sampledMeshes.max(by: { $0.vertices.count < $1.vertices.count }) ?? .empty
                DispatchQueue.main.async {
                    self.progress = 1
                    self.onComplete(best)
                }
            }
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

            let triangleIndices = geometry.triangleIndices.map { Int($0) }

            return FaceMesh3DData(
                vertices: vertices,
                triangleIndices: triangleIndices,
                textureCoordinates: textureCoordinates
            )
        }

        private func updateInstruction(elapsed: TimeInterval) {
            if !faceDetected {
                instruction = "Approche ton visage dans le cercle"
            } else if headAngles.count < 6 {
                instruction = "Tourne lentement la tête — haut, bas, gauche, droite"
            } else if elapsed < scanDuration * 0.7 {
                instruction = "Continue — cartographie 3D en cours"
            } else {
                instruction = "Presque terminé — reste dans le cadre"
            }
        }
    }
}

// MARK: - Overlay Face ID

struct FaceIDScanOverlay: View {
    let progress: Double

    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .mask(
                    ZStack {
                        Rectangle()
                        Circle()
                            .frame(width: 260, height: 260)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                )
                .ignoresSafeArea()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 3)
                    .frame(width: 260, height: 260)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.green, .cyan, .green],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 260, height: 260)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .stroke(Color.white.opacity(pulse ? 0.35 : 0.12), lineWidth: 1.5)
                    .frame(width: 280, height: 280)
                    .scaleEffect(pulse ? 1.02 : 0.98)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
            }

            VStack {
                Image(systemName: "faceid")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 300)
                Spacer()
            }
            .padding(.top, 60)
        }
        .onAppear { pulse = true }
    }
}
