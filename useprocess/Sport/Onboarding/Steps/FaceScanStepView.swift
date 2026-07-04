import SwiftUI

/// Scan visage onboarding — même session que l’app (capture + analyse WHOOP + résultats).
struct FaceScanStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var profileService: UnifiedProfileService
    var onComplete: () -> Void
    var onBack: () -> Void

    var body: some View {
        FaceScanCapturePrivacyGateView(
            onDismiss: {},
            onCancelCapture: onBack,
            onSkip: {
                viewModel.onboardingFaceMesh = nil
                viewModel.onboardingFaceMarkers = nil
                viewModel.isFaceAnalysisCompleted = true
                onComplete()
            },
            onComplete: { result in
                viewModel.onboardingFaceMesh = OnboardingFaceMarkersStore.loadMesh()
                viewModel.onboardingFaceMarkers = result.markers
                viewModel.isFaceAnalysisCompleted = true
                onComplete()
            }
        )
        .environmentObject(profileService)
    }
}
