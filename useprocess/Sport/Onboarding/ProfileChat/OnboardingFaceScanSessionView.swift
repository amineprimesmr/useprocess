//
//  OnboardingFaceScanSessionView.swift
//  useprocess
//

import SwiftUI

/// Scan onboarding hors discussion : capture plein écran → analyse → résultats.
struct OnboardingFaceScanSessionView: View {
    @EnvironmentObject private var profileService: UnifiedProfileService

    /// Relance après kill app : ouvre directement les résultats.
    var initialResult: FaceScanResult? = nil
    var onCancel: () -> Void
    /// Skip pendant la capture (bouton sous « Recommencer le scan »).
    var onSkip: (() -> Void)? = nil
    var onResultReady: (FaceScanResult) -> Void
    var onContinueAfterResults: () -> Void

    @State private var captureInput: CaptureInput?
    @State private var completedResult: FaceScanResult?
    @State private var captureResetToken = 0

    private struct CaptureInput {
        let payload: FaceScanCapturePayload
        let markers: FaceWellnessMarkers
    }

    var body: some View {
        ZStack {
            FaceScanWhoopPalette.canvas.ignoresSafeArea()

            if let input = captureInput, completedResult == nil {
                FaceScanAnalysisFlowView(
                    payload: input.payload,
                    markers: input.markers,
                    profile: profileService.currentProfile,
                    showsResultScreen: false,
                    onDismiss: {},
                    onComplete: { result in
                        withAnimation(Self.pagePushAnimation) {
                            completedResult = result
                        }
                        onResultReady(result)
                    },
                    onRetryScan: {
                        captureResetToken += 1
                        withAnimation(Self.pagePushAnimation) {
                            captureInput = nil
                        }
                    }
                )
                .transition(Self.analysisPushTransition)
                .zIndex(1)
            } else if let result = completedResult {
                OnboardingDedicatedFaceScanResultsView(
                    result: result,
                    onContinue: onContinueAfterResults,
                    onRetryScan: {
                        captureResetToken += 1
                        withAnimation(Self.pagePushAnimation) {
                            completedResult = nil
                            captureInput = nil
                        }
                    }
                )
                .transition(Self.analysisPushTransition)
                .zIndex(2)
            } else {
                FaceScanCaptureScreen(
                    presentation: .fullScreen,
                    onBack: onCancel,
                    onSkip: nil,
                    showsMediaImport: false,
                    allowsScreenFlash: true,
                    skipsHeadTiltPhase: true,
                    usesOnboardingFaceOval: true,
                    onContinue: advanceToAnalysis
                )
                .id(captureResetToken)
                .transition(Self.capturePopTransition)
                .zIndex(0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .processClearUIKitHostingBackground()
        .background(FaceScanWhoopPalette.canvas)
        .presentationBackground(FaceScanWhoopPalette.canvas)
        .animation(Self.pagePushAnimation, value: captureInput?.payload.scanId)
        .animation(Self.pagePushAnimation, value: completedResult?.id)
        .onAppear {
            if completedResult == nil, let initialResult {
                completedResult = initialResult
                onResultReady(initialResult)
            }
        }
    }

    @MainActor
    private func advanceToAnalysis(_ payload: FaceScanCapturePayload, _ markers: FaceWellnessMarkers) {
        withAnimation(Self.pagePushAnimation) {
            captureInput = CaptureInput(payload: payload, markers: markers)
        }
    }

    private static let pagePushAnimation = Animation.onboardingScanPagePush

    private static var analysisPushTransition: AnyTransition {
        .onboardingScanPagePush(direction: .forward)
    }

    private static var capturePopTransition: AnyTransition {
        .onboardingScanPagePush(direction: .backward)
    }
}
