import SceneKit
import SwiftUI

/// Aperçu 3D du mesh visage capturé (onboarding / rapport).
struct FaceMeshPreviewView: UIViewRepresentable {
    let mesh: FaceMesh3DData
    var lineMode: Bool = true

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.scene = SCNScene()
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X

        guard mesh.isValid else { return view }

        let geometry = buildGeometry(from: mesh)
        let node = SCNNode(geometry: geometry)
        node.eulerAngles = SCNVector3(-0.15, Float.pi, 0)
        view.scene?.rootNode.addChildNode(node)

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(0, 0.05, 0.32)
        view.scene?.rootNode.addChildNode(camera)
        view.pointOfView = camera

        context.coordinator.spinNode = node
        context.coordinator.startSpinning()
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.stopSpinning()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var spinNode: SCNNode?
        private var displayLink: CADisplayLink?

        func startSpinning() {
            displayLink = CADisplayLink(target: self, selector: #selector(tick))
            displayLink?.add(to: .main, forMode: .common)
        }

        func stopSpinning() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func tick() {
            spinNode?.eulerAngles.y += 0.012
        }
    }

    private func buildGeometry(from data: FaceMesh3DData) -> SCNGeometry {
        let vertexSource = SCNGeometrySource(
            data: Data(bytes: data.vertices, count: data.vertices.count * MemoryLayout<Float>.size),
            semantic: .vertex,
            vectorCount: data.vertices.count / 3,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 3
        )

        var sources: [SCNGeometrySource] = [vertexSource]

        if data.textureCoordinates.count >= (data.vertices.count / 3) * 2 {
            let uvSource = SCNGeometrySource(
                data: Data(bytes: data.textureCoordinates, count: data.textureCoordinates.count * MemoryLayout<Float>.size),
                semantic: .texcoord,
                vectorCount: data.textureCoordinates.count / 2,
                usesFloatComponents: true,
                componentsPerVector: 2,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<Float>.size * 2
            )
            sources.append(uvSource)
        }

        let indexData = data.triangleIndices.map { UInt32($0) }
        let element = SCNGeometryElement(
            data: Data(bytes: indexData, count: indexData.count * MemoryLayout<UInt32>.size),
            primitiveType: .triangles,
            primitiveCount: indexData.count / 3,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )

        let geometry = SCNGeometry(sources: sources, elements: [element])
        let material = SCNMaterial()
        if lineMode {
            material.fillMode = .lines
            material.diffuse.contents = UIColor.cyan.withAlphaComponent(0.9)
        } else {
            material.diffuse.contents = UIColor(red: 0.88, green: 0.78, blue: 0.72, alpha: 1)
            material.lightingModel = .physicallyBased
        }
        material.isDoubleSided = true
        geometry.materials = [material]
        return geometry
    }
}
