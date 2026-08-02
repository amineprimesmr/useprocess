//
//  OnboardingFaceScanSessionView.swift
//  useprocess
//

import SwiftUI

/// Scan onboarding hors discussion : capture plein écran → analyse → résultats.
struct OnboardingFaceScanSessionView: View {
    @EnvironmentObject private var profileService: UnifiedProfileService

    var isSigningIn: Bool
    var onCancel: () -> Void
    var onResultReady: (FaceScanResult) -> Void
    var onContinueAfterResults: () -> Void

    @State private var captureInput: CaptureInput?
    @State private var completedResult: FaceScanResult?

    private struct CaptureInput {
        let payload: FaceScanCapturePayload
        let markers: FaceWellnessMarkers
    }

    var body: some View {
        ZStack {
            if let input = captureInput, completedResult == nil {
                FaceScanAnalysisFlowView(
                    payload: input.payload,
                    markers: input.markers,
                    profile: profileService.currentProfile,
                    showsResultScreen: false,
                    onDismiss: {},
                    onComplete: { result in
                        completedResult = result
                        onResultReady(result)
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            } else if let result = completedResult {
                OnboardingDedicatedFaceScanResultsView(
                    result: result,
                    isSigningIn: isSigningIn,
                    onContinue: onContinueAfterResults
                )
                .transition(.opacity)
                .zIndex(2)
            } else {
                FaceScanCaptureScreen(
                    presentation: .fullScreen,
                    onBack: onCancel,
                    showsMediaImport: false,
                    allowsScreenFlash: true,
                    onContinue: advanceToAnalysis
                )
                .transition(.opacity)
                .zIndex(0)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: captureInput?.payload.scanId)
        .animation(.easeInOut(duration: 0.24), value: completedResult?.id)
    }

    @MainActor
    private func advanceToAnalysis(_ payload: FaceScanCapturePayload, _ markers: FaceWellnessMarkers) {
        captureInput = CaptureInput(payload: payload, markers: markers)
    }
}
