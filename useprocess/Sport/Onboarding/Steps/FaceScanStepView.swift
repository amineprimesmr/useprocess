import SwiftUI

/// Scan visage onboarding — wrapper autour de `FaceScanCaptureScreen`.
struct FaceScanStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    var onComplete: () -> Void
    var onBack: () -> Void

    var body: some View {
        FaceScanCaptureScreen(onBack: onBack) { payload, markers in
            viewModel.onboardingFaceMesh = payload.mesh
            viewModel.onboardingFaceMarkers = markers
            viewModel.isFaceAnalysisCompleted = true
            OnboardingFaceMarkersStore.save(markers: markers, mesh: payload.mesh)
            onComplete()
        }
    }
}
