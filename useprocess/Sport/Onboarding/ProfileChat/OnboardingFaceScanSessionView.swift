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

    @State private var phase: Phase = .capturing
    @State private var completedResult: FaceScanResult?

    private enum Phase {
        case capturing
        case analyzing(FaceScanCapturePayload, FaceWellnessMarkers)
        case results
    }

    var body: some View {
        Group {
            switch phase {
            case .capturing:
                FaceScanCaptureScreen(
                    presentation: .fullScreen,
                    onBack: onCancel,
                    showsMediaImport: false,
                    allowsScreenFlash: true
                ) { payload, markers in
                    let calibrated = OnboardingFaceScanMarkerCalibration.calibrate(markers)
                    withAnimation(.easeInOut(duration: 0.28)) {
                        phase = .analyzing(payload, calibrated)
                    }
                }
                .transition(.opacity)

            case .analyzing(let payload, let markers):
                FaceScanAnalysisFlowView(
                    payload: payload,
                    markers: markers,
                    profile: profileService.currentProfile,
                    showsResultScreen: false,
                    onDismiss: {},
                    onComplete: { result in
                        completedResult = result
                        onResultReady(result)
                        withAnimation(.easeInOut(duration: 0.28)) {
                            phase = .results
                        }
                    }
                )
                .transition(.opacity)

            case .results:
                if let result = completedResult {
                    OnboardingDedicatedFaceScanResultsView(
                        result: result,
                        isSigningIn: isSigningIn,
                        onContinue: onContinueAfterResults
                    )
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: phaseToken)
    }

    private var phaseToken: String {
        switch phase {
        case .capturing: return "capturing"
        case .analyzing(let payload, _): return "analyzing-\(payload.scanId)"
        case .results: return "results-\(completedResult?.id ?? "")"
        }
    }
}
