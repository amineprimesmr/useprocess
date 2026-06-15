import SwiftUI

/// Étape onboarding — scan visage 3D ARKit TrueDepth + analyse bien-être.
struct FaceScanStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    var onComplete: () -> Void
    var onBack: () -> Void

    @State private var scanProgress: Double = 0
    @State private var instruction = "Approche ton visage dans le cercle"
    @State private var capturedMesh: FaceMesh3DData?
    @State private var markers: FaceWellnessMarkers?
    @State private var isScanning = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isScanning {
                scanningLayer
            } else {
                resultLayer
            }

            faceScanBackButton
        }
    }

    private var faceScanBackButton: some View {
        VStack {
            HStack {
                OnboardingBackButton(action: onBack)
                Spacer()
            }
            .padding(.horizontal, OnboardingConstants.headerHorizontalPadding)
            .padding(.top, OnboardingConstants.headerBackButtonTopPadding)

            Spacer()
        }
        .allowsHitTesting(true)
    }

    private var scanningLayer: some View {
        ZStack {
            FaceMeshScanView(
                progress: $scanProgress,
                instruction: $instruction,
                onComplete: handleMeshCaptured
            )
            .ignoresSafeArea()

            FaceIDScanOverlay(progress: scanProgress)

            VStack {
                Spacer()
                VStack(spacing: 12) {
                    Text("SCAN VISAGE 3D")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(instruction)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text("\(Int(scanProgress * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.65))
                .padding(.bottom, 36)
            }
        }
    }

    private var resultLayer: some View {
        VStack(spacing: 20) {
            Spacer()

            if let mesh = capturedMesh, mesh.isValid {
                FaceMeshPreviewView(mesh: mesh)
                    .frame(width: 220, height: 220)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.cyan.opacity(0.35), lineWidth: 2)
                    )
            } else {
                Image(systemName: "face.dashed")
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text("Scan 3D terminé")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            if let markers {
                VStack(spacing: 8) {
                    metricRow("Clarté", markers.skinClarityScore)
                    metricRow("Fatigue", markers.underEyeFatigueScore)
                    metricRow("Gonflement", markers.puffinessScore)
                    metricRow("Symétrie", markers.facialSymmetryScore)
                }
                .padding(20)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 32)

                ForEach(markers.notes.prefix(2), id: \.self) { note in
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()

            Button {
                onComplete()
            } label: {
                Text("CONTINUER")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white, in: RoundedRectangle(cornerRadius: 28))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func metricRow(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text("\(value)/100")
                .font(.headline.bold())
                .foregroundStyle(.white)
        }
    }

    private func handleMeshCaptured(_ mesh: FaceMesh3DData) {
        let result = FaceWellnessAnalyzer.analyze(from: mesh, pose: .faceMesh)
        capturedMesh = mesh
        markers = result
        viewModel.onboardingFaceMesh = mesh.isValid ? mesh : nil
        viewModel.onboardingFaceMarkers = result
        viewModel.isFaceAnalysisCompleted = true
        OnboardingFaceMarkersStore.save(markers: result, mesh: mesh)
        isScanning = false
        HapticManager.shared.notification(.success)
    }
}
