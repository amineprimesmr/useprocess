import SwiftUI

struct FaceScanSessionView: View {
    @EnvironmentObject private var profileService: UnifiedProfileService

    var onDismiss: () -> Void
    var onComplete: (FaceScanResult) -> Void
    /// Passe directement au callback (coach handoff) sans écran résultat.
    var skipResultSheet: Bool = false
    var onCancelCapture: (() -> Void)? = nil
    var onSkipCapture: (() -> Void)? = nil
    var showsMediaImport: Bool = false
    var compactSkipAction: Bool = false

    @State private var captureInput: CaptureInput?

    private struct CaptureInput {
        let payload: FaceScanCapturePayload
        let markers: FaceWellnessMarkers
    }

    var body: some View {
        ZStack {
            FaceScanWhoopPalette.canvas.ignoresSafeArea()

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
                        },
                        onRetryScan: {
                            captureInput = nil
                        }
                    )
                    .transition(.opacity)
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
                        onContinue: { payload, markers in
                            captureInput = CaptureInput(payload: payload, markers: markers)
                        }
                    )
                    .transition(.opacity)
                }
            }
            .id(captureInput?.payload.scanId ?? "capturing")
        }
        .processClearUIKitHostingBackground()
        .background(FaceScanWhoopPalette.canvas)
        .presentationBackground(FaceScanWhoopPalette.canvas)
        .interactiveDismissDisabled(captureInput != nil)
    }
}

/// Conservé pour compat — préférer `FaceScanResultView`.
typealias FaceScanResultSheet = FaceScanResultView
