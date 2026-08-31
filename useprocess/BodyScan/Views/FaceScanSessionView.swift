import SwiftUI

struct FaceScanSessionView: View {
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.colorScheme) private var colorScheme

    var onDismiss: () -> Void
    var onComplete: (FaceScanResult) -> Void
    /// Passe directement au callback (coach handoff) sans écran résultat.
    var skipResultSheet: Bool = false
    var onCancelCapture: (() -> Void)? = nil
    var onSkipCapture: (() -> Void)? = nil
    var showsMediaImport: Bool = false
    var compactSkipAction: Bool = false
    var usesAppScreenBackground: Bool = false
    var playsArrivalCountdown: Bool = false
    var arrivalCountdownDelay: TimeInterval = 0
    /// Capture → analyse : même push droite→gauche que le reste de l’onboarding.
    var usesOnboardingPageTransitions: Bool = false

    @State private var captureInput: CaptureInput?

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

            Group {
                if let input = captureInput {
                    FaceScanAnalysisFlowView(
                        payload: input.payload,
                        markers: input.markers,
                        profile: profileService.currentProfile,
                        showsResultScreen: !skipResultSheet,
                        onDismiss: onDismiss,
                        onComplete: { result in
                            onComplete(result)
                            if skipResultSheet {
                                onDismiss()
                            }
                        }
                    )
                    .transition(pageTransition)
                } else {
                    FaceScanCaptureScreen(
                        presentation: .fullScreen,
                        onBack: {
                            if let onCancelCapture {
                                onCancelCapture()
                            } else {
                                onDismiss()
                            }
                        },
                        onSkip: onSkipCapture,
                        showsMediaImport: showsMediaImport,
                        compactSkipAction: compactSkipAction,
                        skipsHeadTiltPhase: true,
                        usesOnboardingFaceOval: true,
                        usesAppScreenBackground: usesAppScreenBackground,
                        playsArrivalCountdown: playsArrivalCountdown,
                        arrivalCountdownDelay: arrivalCountdownDelay,
                        onContinue: { payload, markers in
                            withAnimation(transitionAnimation) {
                                captureInput = CaptureInput(payload: payload, markers: markers)
                            }
                        }
                    )
                    .transition(pageTransition)
                }
            }
            .id(captureInput?.payload.scanId ?? "capturing")
        }
        .processClearUIKitHostingBackground()
        .background(sessionBackground)
        .presentationBackground(sessionBackground)
        .interactiveDismissDisabled(captureInput != nil)
        .animation(transitionAnimation, value: captureInput?.payload.scanId)
        .onDisappear {
            FaceScanScreenFlash.shared.deactivate(animated: false)
        }
    }

    private var transitionAnimation: Animation {
        usesOnboardingPageTransitions ? OnboardingScanFlowMotion.animation : .easeInOut(duration: 0.28)
    }

    private var pageTransition: AnyTransition {
        usesOnboardingPageTransitions
            ? OnboardingScanFlowMotion.forwardTransition
            : .opacity
    }
}

/// Conservé pour compat — préférer `FaceScanResultView`.
typealias FaceScanResultSheet = FaceScanResultView
