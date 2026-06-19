import SwiftUI

/// Scan visage onboarding — wrapper autour de `FaceScanCaptureScreen`.
struct FaceScanStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    var onComplete: () -> Void
    var onBack: () -> Void

    var body: some View {
        FaceScanCapturePrivacyGateView(
            onBack: onBack,
            onSkip: {
                viewModel.onboardingFaceMesh = nil
                viewModel.onboardingFaceMarkers = nil
                viewModel.isFaceAnalysisCompleted = true
                onComplete()
            },
            onCapture: { payload, markers in
                viewModel.onboardingFaceMesh = payload.mesh
                viewModel.onboardingFaceMarkers = markers
                viewModel.isFaceAnalysisCompleted = true
                OnboardingFaceMarkersStore.save(markers: markers, mesh: payload.mesh)
                onComplete()
            }
        )
    }
}
