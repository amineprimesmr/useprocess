import SwiftUI

struct FaceScanSessionView: View {
    @EnvironmentObject private var profileService: UnifiedProfileService

    var onDismiss: () -> Void
    var onComplete: (FaceScanResult) -> Void
    /// Passe directement au callback (coach handoff) sans écran résultat.
    var skipResultSheet: Bool = false

    @State private var phase: Phase = .capturing

    private enum Phase {
        case capturing
        case analysis(FaceScanCapturePayload, FaceWellnessMarkers)
    }

    var body: some View {
        Group {
            switch phase {
            case .capturing:
                FaceScanCaptureScreen(onBack: onDismiss) { payload, markers in
                    withAnimation(.easeInOut(duration: 0.28)) {
                        phase = .analysis(payload, markers)
                    }
                }
                .transition(.opacity)

            case .analysis(let payload, let markers):
                FaceScanAnalysisFlowView(
                    payload: payload,
                    markers: markers,
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
                .transition(.opacity)
            }
        }
        .id(phaseToken)
        .animation(.easeInOut(duration: 0.28), value: phaseToken)
    }

    private var phaseToken: String {
        switch phase {
        case .capturing: return "capturing"
        case .analysis(let payload, _): return "analysis-\(payload.scanId)"
        }
    }
}

/// Conservé pour compat — préférer `FaceScanResultView`.
typealias FaceScanResultSheet = FaceScanResultView
