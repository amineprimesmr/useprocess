//
//  OnboardingFaceScanSessionView.swift
//  useprocess
//

import SwiftUI

/// Scan onboarding hors discussion : capture plein écran → analyse → résultats.
struct OnboardingFaceScanSessionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var profileService: UnifiedProfileService

    /// Relance après kill app : ouvre directement les résultats.
    var initialResult: FaceScanResult? = nil
    /// Fond identique aux pages app (aperçu dashboard) au lieu du canvas scan onboarding.
    var usesAppScreenBackground: Bool = false
    /// Chrono 3-2-1 à la place du titre à l’arrivée (premier scan onboarding).
    var playsArrivalCountdown: Bool = false
    var onCancel: () -> Void
    /// Skip pendant la capture (bouton sous « Recommencer le scan »).
    var onSkip: (() -> Void)? = nil
    var onResultReady: (FaceScanResult) -> Void
    var onContinueAfterResults: () -> Void

    @State private var captureInput: CaptureInput?
    @State private var completedResult: FaceScanResult?
    @State private var captureResetToken = 0
    @State private var didTrackCapturePage = false
    @State private var didTrackAnalyzingPage = false
    @State private var didTrackResultsPage = false

    private struct CaptureInput {
        let payload: FaceScanCapturePayload
        let markers: FaceWellnessMarkers
    }

    private var sessionBackground: Color {
        usesAppScreenBackground
            ? ProcessBackgroundPalette.base(for: colorScheme)
            : FaceScanWhoopPalette.canvas
    }

    var body: some View {
        ZStack {
            sessionBackground.ignoresSafeArea()

            if let input = captureInput, completedResult == nil {
                FaceScanAnalysisFlowView(
                    payload: input.payload,
                    markers: input.markers,
                    profile: profileService.currentProfile,
                    showsResultScreen: false,
                    tracksOnboardingMossFunnel: true,
                    onDismiss: {},
                    onComplete: { result in
                        withAnimation(Self.pagePushAnimation) {
                            completedResult = result
                        }
                        onResultReady(result)
                    }
                )
                .transition(Self.analysisPushTransition)
                .zIndex(1)
                .onAppear { trackAnalyzingPageIfNeeded() }
            } else if let result = completedResult {
                OnboardingDedicatedFaceScanResultsView(
                    result: result,
                    onContinue: onContinueAfterResults
                )
                .transition(Self.analysisPushTransition)
                .zIndex(2)
                .onAppear { trackResultsPageIfNeeded() }
            } else {
                FaceScanCaptureScreen(
                    presentation: .fullScreen,
                    onBack: {
                        ProcessAnalytics.trackMossAction(page: .faceScanCapture, action: "cancelled")
                        onCancel()
                    },
                    onSkip: nil,
                    showsMediaImport: false,
                    allowsScreenFlash: true,
                    skipsHeadTiltPhase: true,
                    usesOnboardingFaceOval: true,
                    usesAppScreenBackground: usesAppScreenBackground,
                    playsArrivalCountdown: playsArrivalCountdown,
                    onContinue: advanceToAnalysis
                )
                .id(captureResetToken)
                .transition(Self.capturePopTransition)
                .zIndex(0)
                .onAppear { trackCapturePageIfNeeded() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .processClearUIKitHostingBackground()
        .background(sessionBackground)
        .presentationBackground(sessionBackground)
        .animation(Self.pagePushAnimation, value: captureInput?.payload.scanId)
        .animation(Self.pagePushAnimation, value: completedResult?.id)
        .onAppear {
            if completedResult == nil, let initialResult {
                completedResult = initialResult
                onResultReady(initialResult)
                trackResultsPageIfNeeded()
            } else if completedResult == nil, captureInput == nil {
                trackCapturePageIfNeeded()
            }
        }
    }

    @MainActor
    private func advanceToAnalysis(_ payload: FaceScanCapturePayload, _ markers: FaceWellnessMarkers) {
        ProcessAnalytics.trackMossAction(page: .faceScanCapture, action: "captured")
        withAnimation(Self.pagePushAnimation) {
            captureInput = CaptureInput(payload: payload, markers: markers)
        }
    }

    private func trackCapturePageIfNeeded() {
        guard !didTrackCapturePage, initialResult == nil, completedResult == nil else { return }
        didTrackCapturePage = true
        ProcessAnalytics.trackMossPageViewed(.faceScanCapture)
    }

    private func trackAnalyzingPageIfNeeded() {
        guard !didTrackAnalyzingPage else { return }
        didTrackAnalyzingPage = true
        ProcessAnalytics.trackMossPageViewed(.faceScanAnalyzing)
    }

    private func trackResultsPageIfNeeded() {
        guard !didTrackResultsPage else { return }
        didTrackResultsPage = true
        ProcessAnalytics.trackMossPageViewed(.faceScanResults)
    }

    private static let pagePushAnimation = Animation.onboardingScanPagePush

    private static var analysisPushTransition: AnyTransition {
        .onboardingScanPagePush(direction: .forward)
    }

    private static var capturePopTransition: AnyTransition {
        .onboardingScanPagePush(direction: .backward)
    }
}
